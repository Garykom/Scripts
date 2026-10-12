# DuckDNS Auto-Update for Debian 12

Простой скрипт для автоматического обновления IPv4 и IPv6 адресов в DuckDNS с использованием systemd таймеров.

## 🛠 Установка

Для установки скрипта выполните следующую команду в терминале:

```bash
wget -O install.sh https://raw.githubusercontent.com/Garykom/Scripts/main/duck_install.sh && sudo bash duck_install.sh && rm duck_install.sh
```

### Что произойдет при запуске:
1. Скрипт проверит наличие `curl` и установит его, если нужно.
2. Автоматически определит ваш основной сетевой интерфейс (WAN).
3. Запросит у вас **Домен** и **Токен** DuckDNS.
4. Создаст конфигурационный файл `/etc/duckdns.conf`.
5. Создаст systemd-сервис и таймер для автоматического обновления каждые 15 минут.

## ⚙️ Управление и диагностика

**Проверить, работает ли таймер:**
```bash
systemctl status duckdns.timer
```

**Запустить обновление IP вручную:**
```bash
sudo systemctl start duckdns.service
```

**Посмотреть историю обновлений (логи):**
```bash
journalctl -u duckdns.service
```

**Изменить настройки (домен, токен или интерфейс):**
```bash
sudo nano /etc/duckdns.conf
```
*После редактирования файла настроек изменения вступят в силу при следующем автоматическом запуске.*

## 📁 Структура файлов в системе
- `/etc/duckdns.conf` — настройки (хранится секретный токен).
- `/usr/local/bin/duckdns-update.sh` — основной исполняемый скрипт.
- `/etc/systemd/system/duckdns.service` — описание службы systemd.
- `/etc/systemd/system/duckdns.timer` — расписание запуска.
- `/var/log/duckdns/` — логи ответов от сервера DuckDNS.
