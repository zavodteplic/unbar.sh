![unbar.sh]

### Скрипт настройки `VDS 'TimeWeb'` на `Ubuntu 18.04`

##### Запуск скрипта:

`wget -O - https://raw.githubusercontent.com/GoodVir/unbar.sh/master/unbar.sh > /tmp/unbar.sh && bash /tmp/unbar.sh`

##### На данный момент реализовано:

- Обновление системных пакетов
- Настройка часового пояса `Europe/Moscow`
- Настройка языка и региональных стандартов
- Установка и настройка утилит:
    - `fail2ban`
    - `ufw`
    - `mc`
    - `curl`
    - `wget`
    - `git`
    - `net-tools`
- Настройка параметров `SSH`
- Создание пользователя c правами `sudo`
- Настройка `Bash aliases`:
    - `c='clear'`
    - `smc='sudo mc'`
    - `ping='ping -c 5'`
    - `getip='wget -qO- ifconfig.co'`
    - `ports='netstat -tulanp'`
    - `d='docker'`
    - `dc='docker-compose'`
- Установка `Docker Engine - Community` и `containerd`
- Установка `Docker Compose`
- Очистка пакетного менеджера
- Настройка контейнера `Nginx`
- Настройка контейнера `MySQL` и `PHPMyAdmin`

##### Что возможно будет реализовано в будущем:

- Частный репозиторий `Docker`
- Автоматический деплой из частного репозитория
- Интерфейс для управления и настройки

[unbar.sh]: <./logo.jpg>
