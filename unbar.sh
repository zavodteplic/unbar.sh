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
  apt-get update && \
  apt-get upgrade -y && \
  apt-get dist-upgrade -y
check

# === НАСТРОЙКА ЧАСОВОГО ПОЯСА === #

run "Настройка часового пояса"
  ln -fs /usr/share/zoneinfo/Europe/Moscow /etc/localtime  && \
  apt-get install -y tzdata  && \
  dpkg-reconfigure --frontend noninteractive tzdata  && \
  apt-get install -y ntp
check

# === НАСТРОЙКА ЯЗЫКА И РЕГИОНАЛЬНЫХ СТАНДАРТОВ === #

run "Настройка языка и региональных стандартов"
  apt-get install -y language-pack-ru
  locale-gen ru_RU && \
  locale-gen ru_RU.UTF-8 && \
  update-locale LANG=ru_RU.UTF-8 && \
  dpkg-reconfigure --frontend noninteractive locales
check

# === НАСТРОЙКА ЗАЩИТЫ ОТ ПЕРЕБОРА ПАРОЛЕЙ === #

run "Установка утилиты fail2ban"
  apt-get install -y fail2ban
check

# === НАСТРОЙКА FIREWALL === #

run "Установка и настройка утилиты ufw"
  apt-get install -y ufw && \
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
  apt-get install -y sed && \
  sed -i "/Port\ /d" /etc/ssh/sshd_config && \
  sed -i "/PermitRootLogin\ /d" /etc/ssh/sshd_config && \
  sed -i "/AllowUsers\ /d" /etc/ssh/sshd_config && \
  sed -i "/PermitEmptyPasswords\ /d" /etc/ssh/sshd_config && \
  {
    echo "Port ${port}"
    echo "PermitRootLogin no"
    echo "AllowUsers ${username}"
    echo "PermitEmptyPasswords no"
  } > /etc/ssh/sshd_config
check

# === УСТАНОВКА ПРОГРАММ === #

run "Установка и настройка утилиты mc"
  apt-get install -y mc && \
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
  apt-get install -y curl
check

run "Установка утилиты wget"
  apt-get install -y wget
check

run "Установка утилиты git"
  apt-get install -y git
check

run "Установка утилиты net-tools"
  apt-get install -y net-tools
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
  apt-get install -y apt-transport-https ca-certificates gnupg-agent software-properties-common
check

run "Установка официального ключа GPG Docker"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
check

run "Добавление репозитория Docker"
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
  apt-get update
check

run "Установка Docker Engine - Community и containerd"
  apt-get install -y docker-ce docker-ce-cli containerd.io
check

run "Настройка прав доступа для запуска Docker"
  usermod -aG docker ${username}
check

run "Загрузка текущей стабильной версии Docker Compose"
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
check

run "Настройка прав доступа для запуска Docker Compose"
  chown :docker /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
check

# === СОЗДАНИЕ СТРУКТУРЫ ПРОЕКТА === #

# todo сделать pull образов docker

project="/home/${username}/app"
crt="${project}/web/letsencrypt"

run "Создание каталогов для MySQL и PMA"
  mkdir ${project} && \
  mkdir ${project}/db && \
  mkdir ${project}/db/mysql
check

run "Создание docker-compose.yml для MySQL и PMA"
  {
    echo -e "version: \"3.7\""
    echo -e "services:\n"
    echo -e "  mysql:"
    echo -e "    image: mysql"
    echo -e "    container_name: mysql"
    echo -e "    restart: always"
    echo -e "    command: --default-authentication-plugin=mysql_native_password"
    echo -e "    environment:"
    echo -e "      - MYSQL_ROOT_PASSWORD=${password}"
    echo -e "    ports:"
    echo -e "      - \"3306:3306\""
    echo -e "    volumes:"
    echo -e "      - ./mysql:/var/lib/mysql\n"
    echo -e "  pma:"
    echo -e "    image: phpmyadmin/phpmyadmin"
    echo -e "    container_name: pma"
    echo -e "    restart: always"
    echo -e "    depends_on:"
    echo -e "      - mysql"
    echo -e "    environment:"
    echo -e "      - PMA_HOST=mysql"
    echo -e "      - PMA_ABSOLUTE_URI=http://${domain}/pma/\n"
    echo -e "networks:"
    echo -e "  default:"
    echo -e "    name: app"
  } > ${project}/db/docker-compose.yml
check

run "Создание каталогов для Nginx"
  mkdir ${project}/web && \
  mkdir ${project}/web/nginx && \
  mkdir ${project}/web/nginx/conf.d && \
  mkdir ${project}/web/nginx/errand && \
  mkdir ${project}/web/nginx/log && \
  mkdir ${project}/web/nginx/log/${domain} && \
  mkdir ${project}/web/letsencrypt && \
  mkdir ${project}/web/letsencrypt/${domain}
check

run "Создание файла nginx.conf"
  {
    echo -e "user  nginx;"
    echo -e "worker_processes  auto;\n"
    echo -e "error_log  /var/log/nginx/error.log warn;"
    echo -e "pid        /var/run/nginx.pid;\n"
    echo -e "events {"
    echo -e "    use epoll;"
    echo -e "    worker_connections  1024;"
    echo -e "    multi_accept on;\n}\n"
    echo -e "http {"
    echo -e "    include /etc/nginx/mime.types;"
    echo -e "    default_type application/octet-stream;\n"
    echo -e "    # Логи доступа"
    echo -e "    access_log /var/log/nginx/access.log;\n"
    echo -e "    # Метод отправки данных sendfile"
    echo -e "    sendfile on;\n"
    echo -e "    # Отправлять заголовки и начало файла в одном пакете"
    echo -e "    tcp_nopush on;"
    echo -e "    tcp_nodelay on;\n"
    echo -e "    # Настройка соединения"
    echo -e "    keepalive_timeout 30;"
    echo -e "    keepalive_requests 100;"
    echo -e "    reset_timedout_connection on;"
    echo -e "    client_body_timeout 10;"
    echo -e "    send_timeout 2;\n"
    echo -e "    server_tokens off;"
    echo -e "    server_names_hash_bucket_size 64;\n"
    echo -e "    # Кэширование файлов"
    echo -e "    open_file_cache max=200000 inactive=20s;"
    echo -e "    open_file_cache_valid 30s;"
    echo -e "    open_file_cache_min_uses 2;"
    echo -e "    open_file_cache_errors on;\n"
    echo -e "    # Настройки SSL"
    echo -e "    ssl_session_cache   shared:SSL:10m;"
    echo -e "    ssl_session_timeout 5m;"
    echo -e "    ssl_stapling on;"
    echo -e "    ssl_buffer_size 8k;"
    echo -e "    ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;"
    echo -e "    ssl_ciphers  \"RC4:HIGH:!aNULL:!MD5:!kEDH\";"
    echo -e "    ssl_prefer_server_ciphers on;\n"
    echo -e "    # Сжимать все файлы с перечисленными типами"
    echo -e "    gzip on;"
    echo -e "    gzip_disable \"msie6\";"
    echo -e "    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;\n"
    echo -e "    server {"
    echo -e "        listen 80 default_server;"
    echo -e "        listen 443 default_server;"
    echo -e "        server_name localhost;"
    echo -e "        return 444;"
    echo -e "    }\n"
    echo -e "    include /etc/nginx/conf.d/*.conf;\n}"
  } > ${project}/web/nginx/nginx.conf
check

run "Создание файла errand.inc"
  {
    echo -e "set \$pages /etc/nginx/errand;\n"
    echo -e "error_page 401 /401.html;"
    echo -e "location = /401.html {"
    echo -e "    root \$pages;\n}\n"
    echo -e "error_page 403 /403.html;"
    echo -e "location = /403.html {"
    echo -e "    root \$pages;\n}\n"
    echo -e "error_page 404 /404.html;"
    echo -e "location = /404.html {"
    echo -e "    root \$pages;\n}\n"
    echo -e "error_page 500 /500.html;"
    echo -e "location = /500.html {"
    echo -e "    root \$pages;\n}\n"
    echo -e "error_page 502 /502.html;"
    echo -e "location = /502.html {"
    echo -e "    root \$pages;\n}\n"
    echo -e "error_page 503 /503.html;"
    echo -e "location = /503.html {"
    echo -e "    root \$pages;\n}"
  } > ${project}/web/nginx/errand/errand.inc
check

# todo страницы ошибок добавить

run "Создание SSL сертификата для ${domain}"
  openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout ${crt}/${domain}/key.pem -out ${crt}/${domain}/cert.pem -subj "/C=RU/ST=Russia/L=Moscow/CN=${domain}"
check

run "Создание файла ${domain}.conf"
  {
    echo -e "server {"
    echo -e "    listen 80;"
    echo -e "    server_name ${domain};\n"
    echo -e "    location / {"
    echo -e "        return 301 https://\$host\$request_uri;"
    echo -e "    }\n}\n"
    echo -e "server {"
    echo -e "    listen 443 ssl http2;"
    echo -e "    server_name ${domain};\n"

    # todo изменить расположение и смонтировать как том (Добавьте всю /etc/letsencrypt папку как том)
    echo -e "    # Настройка SSL"
    echo -e "    ssl_certificate /etc/letsencrypt/${domain}/cert.pem;"
    echo -e "    ssl_certificate_key /etc/letsencrypt/${domain}/key.pem;"
    echo -e "    add_header Strict-Transport-Security 'max-age=604800';\n"

    echo -e "    # Замена стандартных страниц ошибок Nginx"
    echo -e "    include /etc/nginx/errand/errand.inc;\n"
    echo -e "    # Настройка логирования"
    echo -e "    error_log /var/log/nginx/${domain}/error.log warn;"
    echo -e "    access_log /var/log/nginx/${domain}/access.log;\n"
    echo -e "    # Прокси для PhpMyAdmin"
    echo -e "    location  ~ \/pma {"
    echo -e "        rewrite ^/pma(/.*)$ \$1 break;"
    echo -e "        proxy_set_header X-Real-IP  \$remote_addr;"
    echo -e "        proxy_set_header X-Forwarded-For \$remote_addr;"
    echo -e "        proxy_set_header Host \$host;"
    echo -e "        proxy_pass http://pma:80;"
    echo -e "    }\n}"
  } > ${project}/web/nginx/conf.d/${domain}.conf
check

run "Создание docker-compose.yml для Nginx"
  {
    echo -e "version: \"3.7\""
    echo -e "services:"
    echo -e ""
    echo -e "  nginx:"
    echo -e "    image: nginx"
    echo -e "    container_name: nginx"
    echo -e "    restart: always"
    echo -e "    ports:"
    echo -e "      - \"80:80\""
    echo -e "      - \"443:443\""
    echo -e "    volumes:"
    echo -e "      - ./nginx/nginx.conf:/etc/nginx/nginx.conf"
    # todo ????
    echo -e "      - ./nginx/certs:/etc/nginx/certs"

    echo -e "      - ./nginx/conf.d:/etc/nginx/conf.d"
    echo -e "      - ./nginx/errand:/etc/nginx/errand"
    echo -e "      - ./nginx/log:/var/log/nginx"
    echo -e ""
    echo -e "networks:"
    echo -e "  default:"
    echo -e "    name: app"
  } > ${project}/web/docker-compose.yml
check

run "Изменение владельца и группы созданных файлов"
  chown -R ${username}:${username} /home/${username}/app
check

# todo подумать по поводу открытия порта 3306 или ???? (локально и извне)

# === ОЧИСТКА ПЕРЕД ЗАВЕРШЕНИЕМ === #

run "Очистка пакетного менеджера"
  apt-get autoremove -y && \
  apt-get autoclean -y
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
