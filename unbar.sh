#!/bin/bash

# Цветной фон
back_red="\e[41m"
back_green="\e[42m"
back_brown="\e[43m"
back_blue="\e[44m"
back_purple="\e[45m"
back_cyan="\e[46m"

# Цветной текст
red="\e[31m"
green="\e[32m"
brown="\e[33m"
blue="\e[34m"
purple="\e[35m"
cyan="\e[36m"

# Завершение вывода цвета
end="\e[0m"

# Данные о системе
os=`lsb_release -a | grep "Description" | awk '{$1=""; print $0}'`
cpu=`lscpu | grep "CPU MHz" | awk '{print $3}'`
cores=`grep -o "processor" <<< "$(cat /proc/cpuinfo)" | wc -l`
kern=`uname -r | sed -e "s/-/ /" | awk '{print $1}'`
kn=`lsb_release -cs`
mem=`free -m | grep "Mem" | awk '{print $2}'`
hdd=`df -m | awk '(NR == 2)' | awk '{print $2}'`

run() {
  # Печать информации о выполнении новой команды
  echo -e "${purple}[RUN] ${1}...${end}"
}

check() {
  # Проверка состояния вызова команды
  temp=$?
  echo "Status code of the executed command: ${temp}"
  if [[ temp -eq 0 ]]; then
	echo -en "${cyan}[SUCCESS] Команда успешно выполнена${end}\n\n"
  else
	echo -e "${back_red}[ERROR]${end} ${red}Ошибка выполнения команды${end}"
	echo -en "\n${green}Продолжить выполнение скрипта? [Y/n]: ${end}"
	answer; if [[ $? -ne 0 ]]; then close; fi
  fi
}

answer() {
  # Соглашение пользователя на продолжение
  temp=""
  read temp
  temp=$(echo ${temp^^})
  echo -e "${end}"
  if [[ "$temp" != "Y" && "$temp" != "YES" ]]; then return 255; fi
}

close() {
  # Завершение работы скрипта + перезагрузка
  echo -en "${brown}Нажмите любую клавишу, чтобы продолжить...${end}"
  read -s -n 1
  clear
  if [[ "$1" == "reboot" ]]; then shutdown -r now; else exit 0; fi
}

# Вывод информации о скрипте
clear
clr=$(echo -e "${red}*${green}*${brown}*${blue}*${purple}*${cyan}*${brown}")
echo -en "$brown"
echo "┌─────────────────────────────────────────────┐"
echo "│       ${clr}   UNBAR.SH  v0.0.1             │"
echo "├─────────────────────────────────────────────┤"
echo "│ Данный скрипт выполняет первичную настройку │"
echo "│ сервера VDS 'TimeWeb' на базе Ubuntu 18.04  │"
echo "└─────────────────────────────────────────────┘"
echo -en "$end"

# Вывод информации о системе
echo -e "$red"
echo "  Дистрибутив:${os}"
echo "  Версия ядра: ${kern} (${kn})"
echo "          CPU: ${cores} x ${cpu} MHz"
echo "          RAM: ${mem} Mb"
echo "          HDD: ${hdd} Mb"
echo -en "$end"

# Подготовка необходимых данных
port=$(shuf -i 50000-60000 -n 1)
echo -en "\n${cyan}Введите имя нового пользователя: ${end}"; read username
echo -en "${cyan}Введите пароль нового пользователя: ${end}"; read -r password
echo -en "${cyan}Введите служебный домен: ${end}"; read domain

# Запрос разрешения на запуск скрипта
echo -en "\n${green}Подтвердите запуск скрипта [Y/n]: ${end}"
answer; if [[ $? -ne 0 ]]; then close; fi

# === ОБНОВЛЕНИЕ СИСТЕМНЫХ ПАКЕТОВ === #

run "Обновление системных пакетов"
  apt update && \
  apt upgrade -y && \
  apt dist-upgrade -y
check

# === НАСТРОЙКА ЧАСОВОГО ПОЯСА === #

run "Настройка часового пояса"
  ln -fs /usr/share/zoneinfo/Europe/Moscow /etc/localtime  && \
  apt install -y tzdata  && \
  dpkg-reconfigure --frontend noninteractive tzdata  && \
  apt install -y ntp
check

# === НАСТРОЙКА ЯЗЫКА И РЕГИОНАЛЬНЫХ СТАНДАРТОВ === #

run "Настройка языка и региональных стандартов"
  apt install -y language-pack-ru
  locale-gen ru_RU && \
  locale-gen ru_RU.UTF-8 && \
  update-locale LANG=ru_RU.UTF-8 && \
  dpkg-reconfigure --frontend noninteractive locales
check

# === НАСТРОЙКА ЗАЩИТЫ ОТ ПЕРЕБОРА ПАРОЛЕЙ === #

run "Установка утилиты fail2ban"
  apt install -y fail2ban
check

# === НАСТРОЙКА FIREWALL === #

run "Установка и настройка утилиты ufw"
  apt install -y ufw && \
  ufw default deny incoming && \
  ufw default allow outgoing && \
  ufw allow http && \
  ufw allow 443/tcp && \
  ufw allow ${port}
check

run "Включение ufw"
  yes | ufw enable
check

run "Проверка статуса ufw"
  ufw status
check

# === НАСТРОЙКА SSH === #

run "Настройка параметров SSH"
  apt install -y sed && \
  sed -i "/Port\ /d" /etc/ssh/sshd_config && \
  sed -i "/PermitRootLogin\ /d" /etc/ssh/sshd_config && \
  sed -i "/AllowUsers\ /d" /etc/ssh/sshd_config && \
  sed -i "/PermitEmptyPasswords\ /d" /etc/ssh/sshd_config && \
  {
    echo "Port ${port}"
    echo "PermitRootLogin no"
    echo "AllowUsers ${username}"
    echo "PermitEmptyPasswords no"
  } >> /etc/ssh/sshd_config
check

# === УСТАНОВКА ПРОГРАММ === #

run "Установка и настройка утилиты mc"
  apt install -y mc && \
  {
    echo "[Midnight-Commander]"
    echo "use_internal_view=true"
    echo "use_internal_edit=true"
    echo "editor_syntax_highlighting=true"
    echo "skin=modarin256"
    echo "[Layout]"
    echo "message_visible=0"
    echo "xterm_title=0"
    echo "command_prompt=0"
    echo "[Panels]"
    echo "show_mini_info=false"
  } > /etc/mc/mc.ini
check

run "Установка утилиты curl"
  apt install -y curl
check

run "Установка утилиты wget"
  apt install -y wget
check

run "Установка утилиты git"
  apt install -y git
check

run "Установка утилиты net-tools"
  apt install -y net-tools
check

# === СОЗДАНИЕ НОВОГО ПОЛЬЗОВАТЕЛЯ === #

run "Создание пользователя ${username}"
  groupadd ${username} && \
  useradd -g ${username} -G sudo -s /bin/bash -m ${username} -p $(openssl passwd -1 ${password})
check

run "Настройка Bash aliases"
  {
    echo "alias c='clear'"
    echo "alias smc='sudo mc'"
    echo "alias ping='ping -c 5'"
    echo "alias getip='wget -qO- ifconfig.co'"
    echo "alias ports='netstat -tulanp'"
    echo "alias d='docker'"
    echo "alias dc='docker-compose'"
  } > /home/${username}/.bash_aliases && \
  chown ${username}:${username} /home/${username}/.bash_aliases
check

# === УСТАНОВКА DOCKER === #

run "Установка пакетов для использования хранилища поверх HTTPS"
  apt install -y apt-transport-https ca-certificates gnupg-agent software-properties-common
check

run "Установка официального ключа GPG Docker"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
check

run "Добавление репозитория Docker"
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
  apt update
check

run "Установка Docker Engine - Community и containerd"
  apt install -y docker-ce docker-ce-cli containerd.io
check

run "Настройка прав доступа для запуска Docker"
  usermod -aG docker ${username}
check

run "Загрузка текущей стабильной версии Docker Compose"
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
check

run "Настройка прав доступа для запуска Docker Compose"
  chown :docker /usr/local/bin/docker-compose && \
  chmod +x /usr/local/bin/docker-compose
check

# === СОЗДАНИЕ СТРУКТУРЫ ПРОЕКТА === #

project="/home/${username}/app"

run "Создание каталогов для MySQL и PMA"
  mkdir -p ${project}/db/mysql
check

run "Создание docker-compose.yml для MySQL и PMA"
cat > ${project}/db/docker-compose.yml << EOF
version: "3.7"
services:

  mysql:
    image: mysql
    container_name: mysql
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    environment:
      - MYSQL_ROOT_PASSWORD=${password}
    ports:
      - "3306:3306"
    volumes:
      - ./mysql:/var/lib/mysql

  pma:
    image: phpmyadmin/phpmyadmin
    container_name: pma
    restart: always
    depends_on:
      - mysql
    environment:
      - PMA_HOST=mysql
      - PMA_ABSOLUTE_URI=https://${domain}/pma/

networks:
  default:
    name: app
EOF
check

run "Создание каталогов для Nginx"
  mkdir -p ${project}/web/nginx/{conf.d,errand} && \
  mkdir -p ${project}/web/nginx/log/${domain} && \
  mkdir -p /etc/letsencrypt/${domain}
check

run "Создание файла nginx.conf"
cat > ${project}/web/nginx/nginx.conf << EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    use epoll;
    worker_connections  1024;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Логи доступа
    access_log /var/log/nginx/access.log;

    # Метод отправки данных sendfile
    sendfile on;

    # Отправлять заголовки и начало файла в одном пакете
    tcp_nopush on;
    tcp_nodelay on;

    # Настройка соединения
    keepalive_timeout 30;
    keepalive_requests 100;
    reset_timedout_connection on;
    client_body_timeout 10;
    send_timeout 2;

    # Параметры сервера
    server_tokens off;
    server_names_hash_bucket_size 64;

    # Кэширование файлов
    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # Настройки SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1440m;
    ssl_stapling on;
    ssl_buffer_size 8k;
    ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    # Сжимать файлы
    gzip on;
    gzip_disable "msie6";
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;

    server {
        listen 80 default_server;
        listen 443 default_server;
        server_name localhost;
        return 444;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF
check

run "Создание файла errand.inc"
cat > ${project}/web/nginx/errand/errand.inc << EOF
set \$pages /etc/nginx/errand;

error_page 401 /401.html;
location = /401.html {
    root \$pages;
}

error_page 403 /403.html;
location = /403.html {
    root \$pages;
}

error_page 404 /404.html;
location = /404.html {
    root \$pages;
}

error_page 500 /500.html;
location = /500.html {
    root \$pages;
}

error_page 502 /502.html;
location = /502.html {
    root \$pages;
}

error_page 503 /503.html;
location = /503.html {
    root \$pages;
}
EOF
check

# todo страницы ошибок добавить

run "Создание SSL сертификата для ${domain}"
  openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout /etc/letsencrypt/${domain}/key.pem -out /etc/letsencrypt/${domain}/cert.pem -subj "/C=RU/ST=Russia/L=Moscow/CN=${domain}"
check

run "Создание файла ${domain}.conf"
cat > ${project}/web/nginx/conf.d/${domain}.conf << EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    # todo изменить расположение и смонтировать как том (Добавьте всю /etc/letsencrypt папку как том)

    # Настройка SSL
    ssl_certificate /etc/letsencrypt/${domain}/cert.pem;
    ssl_certificate_key /etc/letsencrypt/${domain}/key.pem;
    add_header Strict-Transport-Security 'max-age=604800';

    # Замена стандартных страниц ошибок Nginx
    include /etc/nginx/errand/errand.inc;

    # Настройка логирования
    error_log /var/log/nginx/${domain}/error.log warn;
    access_log /var/log/nginx/${domain}/access.log;

    # Прокси для PhpMyAdmin
    location  ~ \/pma {
        rewrite ^/pma(/.*)$ \$1 break;
        proxy_set_header X-Real-IP  \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$host;
        proxy_pass http://pma:80;
    }
}
EOF
check

run "Создание docker-compose.yml для Nginx"
cat > ${project}/web/docker-compose.yml << EOF
version: "3.7"
services:

  nginx:
    image: nginx
    container_name: nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/errand:/etc/nginx/errand
      - ./nginx/log:/var/log/nginx

networks:
  default:
    name: app
EOF
check

run "Изменение владельца и группы созданных файлов"
  chown -R ${username}:${username} ${project}
check

run "Загрузка используемых образов Docker"
  docker pull mysql && \
  docker pull phpmyadmin/phpmyadmin && \
  docker pull nginx
check

# === ОЧИСТКА ПЕРЕД ЗАВЕРШЕНИЕМ === #

run "Очистка пакетного менеджера"
  apt autoremove -y && \
  apt autoclean -y
check

# === ЗАВЕРШЕНИЕ РАБОТЫ СКРИПТА === #

ip=$(wget -qO- ifconfig.co)

echo -e "${clr}${clr}${clr}${clr}${clr}${clr}${end}"

echo -e "${green}  Пользователь: ${cyan}${username} ${end}"
echo -e "${green}        Пароль: ${cyan}${password} ${end}"
echo -e "${green}      Порт SSH: ${cyan}${port}${end}"
echo -e "${green}    Внешний IP: ${cyan}${ip}${end}"

echo -e "${clr}${clr}${clr}${clr}${clr}${clr}${end}"

echo -e "\n${cyan}ssh ${username}@${ip} -p ${port}${end}"
echo -e "${cyan}sh://${username}@${ip}:${port}/${end}"

echo -e "\n${red}[ВНИМАНИЕ] Система будет перезагружена!${end}"
echo -e "${red}Сохраните данные указанные выше!${end}\n"

close "reboot"

# todo подумать по поводу открытия порта 3306 или ???? (локально и извне)
# todo logrotate поставить настроить
