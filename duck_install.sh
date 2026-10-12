#!/bin/sh

# Проверка на запуск от root
if [ "$(id -u)" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root (sudo bash install.sh)"
  exit 1
fi

echo
echo "--- Установка DuckDNS Auto-Update для Debian 12 ---"

echo
# 1. Установка зависимостей
echo "[1/6] Установка curl..."
apt update && apt install -y curl

# 2. Автоматическое определение WAN интерфейса
# Пытаемся узнать интерфейс, через который идет трафик в интернет
DETECTED_IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')

if [ -z "$DETECTED_IFACE" ]; then
    DETECTED_IFACE="eth0" # Запасной вариант, если определение не удалось
fi

echo
# 3. Интерактивный сбор настроек
echo "[2/6] Настройка параметров..."

read -p "Введите ваш домен DuckDNS (без .duckdns.org): " USER_DOMAIN
if [ -z "$USER_DOMAIN" ]; then
    echo "Ошибка: Домен обязателен."
    exit 1
fi

read -p "Введите ваш Token: " USER_TOKEN
if [ -z "$USER_TOKEN" ]; then
    echo "Ошибка: Токен обязателен."
    exit 1
fi

read -p "Введите сетевой интерфейс [$DETECTED_IFACE]: " USER_IFACE
# Если пользователь просто нажал Enter, используем определенный интерфейс
USER_IFACE=${USER_IFACE:-$DETECTED_IFACE}

echo
# 4. Создание конфигурационного файла с введенными данными
echo "[3/6] Сохранение настроек в /etc/duckdns.conf..."
cat << EOF > /etc/duckdns.conf
DOMAIN=$USER_DOMAIN
TOKEN=$USER_TOKEN
IFACE=$USER_IFACE
LOG_DIR=/var/log/duckdns
EOF
chmod 600 /etc/duckdns.conf

echo
# 5. Создание основного скрипта обновления
echo "[4/6] Создание скрипта обновления..."
cat << 'EOF' > /usr/local/bin/duckdns-update.sh
#!/bin/sh

# Загрузка переменных из конфига (для ручного запуска)
if [ -f /etc/duckdns.conf ]; then
    . /etc/duckdns.conf
fi

if [ -z "$DOMAIN" ] || [ -z "$TOKEN" ]; then
    echo "Error: DOMAIN or TOKEN not set in /etc/duckdns.conf"
    exit 1
fi

mkdir -p "$LOG_DIR"

IPV4=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IPV6=$(ip -6 addr show "$IFACE" | grep 'scope global' | grep -oP '(?<=inet6\s)[a-f0-9:]+')

URLv4="https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=$IPV4"
URLv6="https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ipv6=$IPV6"

echo "url=$URLv4" | curl -k -s -o "$LOG_DIR/duckv4.log" -K -
echo "url=$URLv6" | curl -k -s -o "$LOG_DIR/duckv6.log" -K -

echo "Update complete: $(date)"
EOF
chmod +x /usr/local/bin/duckdns-update.sh
echo

# 6. Создание systemd service и timer
echo "[5/6] Настройка systemd..."
cat << 'EOF' > /etc/systemd/system/duckdns.service
[Unit]
Description=DuckDNS IP Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/duckdns.conf
ExecStart=/usr/local/bin/duckdns-update.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/duckdns.timer
[Unit]
Description=Run DuckDNS Update every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

# Перезагрузка systemd и активация
systemctl daemon-reload
systemctl enable --now duckdns.timer

echo
echo "[6/6] Проверка первой работы..."
echo
systemctl start duckdns.service
echo

echo "Установка успешно завершена!"
echo "-------------------------------------------------------"
echo "Интерфейс: $USER_IFACE"
echo "Домен: $USER_DOMAIN.duckdns.org"
echo "Таймер запущен. Обновление будет происходить каждые 15 минут."
echo "Проверить статус: systemctl status duckdns.timer"
echo "Посмотреть логи: journalctl -u duckdns.service"
echo "-------------------------------------------------------"
echo
