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

function run() {
  # Печать информации о выполнении новой команды
  echo -e "${purple}[RUN] ${1}...${end}"
}

function check() {
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

function answer() {
  # Соглашение пользователя на продолжение
  temp=""
  read temp
  temp=$(echo ${temp^^})
  echo -e "${end}"
  if [[ "$temp" != "Y" && "$temp" != "YES" ]]; then return 255; fi
}

function close() {
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
    echo -e "\n# unbar.sh"
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
    echo "alias ll='ls -la'"
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
  mkdir -p ${project}/web/nginx/conf.d && \
  mkdir -p ${project}/web/nginx/errand && \
  mkdir -p ${project}/web/nginx/ssl && \
  mkdir -p ${project}/web/nginx/log/${domain}
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

    # Сжимать файлы
    gzip on;
    gzip_disable "msie6";
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;

    # Сбросить доступ по IP
    server {
        listen 80 default_server;
        listen 443 default_server;
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        return 444;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF
check

run "Создание файла errand.inc"
cat > "${project}/web/nginx/errand/errand.inc" << EOF
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

function page() {
# Генерация HTML страниц ошибок
cat > "${project}/web/nginx/errand/${1}.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="robots" content="noindex, nofollow">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <link rel="shortcut icon"
        href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAMAAADDpiTIAAAAq1BMVEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA0NbREAAAAOHRSTlMA+wkD9/MH5w0WXtLvdxHd4n9lu9eRGiJN66uIsSXMojsuxDJTKZlEtqdvNnJYyJW/SIRAnmoejE3HxYYAABkLSURBVHja7N3pctowFAXgK7OYNWYHs4ZACCGEEEjT8/5P1mmnM22agCXbiYx6vhfgBxqPpHvulRAREREREREREREREREREREREREREREREWXXbt8eDldPo0N906oMridXQv+TMv6l/Oq4u10uuBL+Cw84qXbTrSyKQk5b4rz8zeHIReCwLaLl2/VFTshJXegJZwN+CFw0hLZwtRByzRQmpi1PyCk+zISjVyF3eDCmZrdCrpggBnUt5Ig7xBDwTOiMFmJoCbmiCXM+TwLueIG5rZAz2jAWloScEcBYU8gdeZgqlIWcUYax70LueICpfE/IHUuYWgk5ZAtDaiLkkC4M3Qu5ZAhDjIS4ZQozYyGnhDDDOrBbPJjZCzllAjPPQk65g5GpkFtaMLIUcksTJjpMgrnmBSYqQo5pw0CDrWHOCWBgI+SaEPpCRkHdM6lCW13IPaUhNNU4MSabys+b7nqXk7jqClpGQllTPNaHDfwykNiOITTkGQXNmPl2XUinTPu6Q7QnoQy5bXbwhupJfMUuoqi+UFb0m4209+iVPM6bCWVD8XGPj3QkkUWAcxRHQmRDadPACUdJ5GqNM4ZCGdDrFj7vI5074LQHIevKozzOyF9JQoMaTmgL2VY6FHDet8+7GD4KWbZsfEVey3vBR3ZCdi2mX9WzsVF4byBkkzdSwFdd1l37TIJlzHMDemqepKB3wyRYlnjdr87s5UYcCpgd86qFvp3HwtvTBVmzVTAxkXTMAw4FzILSPcyM0gsKMQlm3zyAIT8naWkq/FLjUEBbnmswNkjx50P8dBCyY6Ngbizped1xKKA9xRfoMQoGmV8Md4Vs8NaIpy5pahX4PIwV5SliCiRVHAppRT9ANFZunfXm/+ccv//ObQMJ5NnBdeHmId65kCbuIrcMyfV9JFMVa3I1f9higDyRXgAt2Uzw7gHAv//GRRBXuYPzst3Fd8BvjRWfGo+jNEVyNU9sGeCPwrjFLYEh7wYnXMgwrzLeULst14CB3BqpuBFrAvxDtSusJxvGP5O7FVvu8V5+vOR+QFPpCe9d0rteG3woHHG8gKbrDpLzi2LJA05QbXaX6PGaCh+4kKHOxTxOCuq8pdayqCKptdiywxmFJ8YLdOTqeSSjXsWSLs5SM746p2Oyx98u6H3nR0RQY747piG3KcBMRtq5+oikhlwCGvptJHEnlvjQMOapUMMyvMRg0Bg61Ipx82jlIT6U6cmudeip1dlzGG3pI66t2HGEruBRKMrV6tKCQZ6Ctj2DIzoFogsLBlWhT41YJtKcEGRuJXasYCK4E/qcAlGhJFZUYGbG80Ak76BgriVW3MKQzzphtPnucoJBNZiaMTT0KXfDc7GiDWPBtVCU/v5CgkFN/MbjQLpy3wowEhbFhmfEsWN5IFpvDCOPYsMVYqnxbfrYBaKMjfnvIJ4RR5JGK89goC82zBDTnlcCP9i717W0gSAMwLM5cAoQQOQkZ0RAKqKgfvd/ZX1aWwvl4JJssjsh7w30jw07OzPfSmhVTB8MekNQlfRpGgnlLWRVbNJggsCcGqW+t6lD0gtpYLsI7jY9CFzaIDLvubcxQuikgyIylh5kiDxpcIcwVulRUEam5Bg7GHSPUPx0TkTKqI/v1UmDBsJpp60BKXbNxbeGpEEF4bgvlFK0PLAlDToIyUnvhSUV2iYGR/5AWCJ9qkxSo2PgYNAQv7ANvGTmX4PImHdfLQdf2G028JNfGDcY1McuI94+SLSzywO3FL9bIP0GxCl3K4wKjizgEJ/BZpaGdZMGg3pQQqTrgxc1iAwaDGpDCZHeB1xg6ZkzGDSHGk66OqYgXeqVYleFIm46JHSJ6UriRdk4zKBKNo2WC98galHccgKq1NN8ydANoi7FzoMy63RrKOzdsGhQ3Lb4D8fEK64aXf23qjUEY8oplrlWFnt8itsI53FYcjPCkgIpD4K/KKt/NvyAO6Ir1cJ6qqJBNKC43UClypWOCveKgFPNBL0b1jkY9Aqlbq5yYcTq4xdvGb5B9EYxa+EL83dwNNp+RevmAj4/4mgLjswDSA+CytZss/dhlwcmFDMfarlXty+ydLBjkQ+3QfR85h96ypN6CyjmXdnWYNnHnuKjHeb5kaJ1+l9y4T/cl0mtR+xj/SqyDl38b90LEzFX+GabU4xfNxlSZ4n/MH4NTYcaDjnVTPAG0ZpOyrv45NyUhhlSI+NAteIVRYk1XRzjLYM3iKZyU7zuTWmiPybguNXVNAbtMY4Tt7mgz4/c0UkNB3sqg0LDkNnwK20LVXEgbEXY6mfopGccCH0ufIJ64komxCYCB0JXhOUyndQUOEL072YWBdVEBOpXUQtaHg5IVISKBjgO/wgyoZ+QS6+EFf96rnukVk/gtGL3cRSskFVPXEF8yFJoyNde4Lx2p9aky5QQBT/xrwtkPMjwhqTSVOBb/qDWIHkbBGfYtmusSpAgWRGqz3XxPl5ykc6GG5p7FJ+eAwnSFaH6KT75c6GHSHjJvg66wQW6DVJmDgm794V2kCfk0ugIRav16ivCJeTIXxoXEA03wT2BchsXGk91znFmO7V3OmUKJYxYdYrLQOOLSxvIkb80LkIFI7YdYzJEEN6QNPfvxOr12KXxHBGpJPVGeIVgBuUYH/ySLw6qiModJVIBQVVaev7+Di+NpxJ/UeGJRI6IWhUE1303ZJg/++/SuIzIzCmBqgij+Ggbs9bvP3xOlNQRmQSmB+Vd7AtUERozxOE/3OcGiIyXvGWxLQKQmRqVZ9ehkpNFdBIXKD4SCM/fGJHxeVpaCka9UP2coxBsH2wkrCUwgyLZgjHZLtFykxUaMMY+TRVhpgI2ErUr9gKFim92iJ1kNkSPkmOFfdoqQisLNraUGC0oJu4s+sOIWc6/0k/AcSso588oEKsNNhLzCWhBQlw9wirYEEmZDVphj96KMFcEGw+UCC1EpdvQH/G2L/0EHDFGZNySTZcqu2AjEZ+AIaLUn9Cl7sBGIj4BHURKvFp0mbwDNhJwHdgTiJg/MyDdY1faEdj1jBP0VYQNRp8A9k3B00cujRXhA9jIcp8LqCIe83eS1xRgg/loUCaL0/RVhAOw4RFrNcRnNTLoZIp0QPi3PmIkbi2StAAbrHcEhpCgoyKcMvoEcH5SaIu4bcskpQs2GN8HK6sB1VeEE7Dh8k0O+wENJCvCOdh4I67q0MIt2eYdT66xEtxAA+ke4RpscA2RXkAD6YpwBjaYHgP1tF3lK8IxuGB6DPwBHeQrwhewwfMY6EGzds2ga8rrOwaOoN+8SWfcgw2Ox0AjRu/ckm3yNyrJo2G2IYu45yrCJ3DR5hchvYEhzgTP23VwwS89dAtj+DP+mTELYsYyagOrk6ejMmwyYxxuVwGG/bwWa9wDI7jNBhrXb583eWfG3BArOfNG74/HDD6CCdEgTgz7BfjkLTlnxjwSJx2YSHxYfDNjVsSIZeoKtv/CNzOG06ZwC8bq5LlmxnD6DTDoFuhIRcg0M2ZNbNhmf1bXPZaZMYLPqrjp01ZONcMxM6ZGXDzDdHsV4Qd44POgIIPrNfFhsQuMYNMPMGEWSKYiZPTF+vREPHC5W/mqCN+ZfAK49ITZrFy0CwzK1h1FHnNBFpP/T58VIavMmCFxYPA14NGKkFFmzCtxwOVI9VUR8gmM6BMHbMas/hAPOVPblywvA3tgJ3vPpHRlMRjGZsZmV7dh3AzbUQMyH6PojR1tHieXrPlvCttcuqs8Tch0jNKXODI/PPoHUsdczVQIj8MUW47p6eE/2bsThLSBKAzAb7KzEwir7DsiFkXpf/+Ttdbaaishywy8DH5HAEJm3sq8GCj7uEeDM3Kfzi7uh4BMRgGyhPvs6GyEVDPMZh4JyEynVWbxHhc0xxfF7oizGr4ccxW1wdmIqGdakfUhIDuzF7OL8waRLJUDZhbnBqEMDeHPLs6zw7/CQMddRWFgRoprs00wzgdlZ/JmlvHNB3nZKK7OOr6jQrjPBdAE3xbBrHSFZlyFuPo6A55HmZj6igOeovdCcdOCUqIyqPfWi2GvPgj4hBw7hUm9+/TUXU0GLsLonxCcQ5nK0127b9I7h+Xtt4LAJdn1m/ymTO940+1jrwjVnoinLZRwh/kDfS43+xbgIsTOHzn0KXNTWln4jO6xwEfIZ3XbJoWa37g4t6CUo1Bevg51LKYZ4R5kG+Q9Os1pr3BGdmNMEbT8DlSZE0tVyDVpU1TjocB5FG/KFJFxW8U/tB4X5kGq3YjimK9xBsWSRzEYzy4+0HpUzAYSuVuKa1+AasMcxeQ1BP7Suy4wD2lEw6P4zNsiVAqWlMB4gjeaB4MfIUtlSskcJlBGPDqUzK0F2VgOjV1Dkm6ZkjJ9ATU6D5TYtIJ3tJ0TMYAU1i2lsXShwq5JKXhr/KbzNaAIGTobSucQQL6FSen4kMonfnKQwR1TWuUJZLuh1PICLzSeFjaCBMGB0jNW+INP9q1tAYDGO+RqSK9QJhmcHn7jNJ1xaUGaIvFzg9SqB5LD2HF7/l+0BaRhODO2i7Q6fZKlXOD0/v+wq1zb0vABUrKnJE+zAvArvvC5vZZeMZkNsiWZphZkuHfoJ34Zc37pIINbz+MzJCi2SKpyRdt7YB/pFAwiYheanpFkG0vXiaF7pGL3STavgrS+0V+8mmeqxE2e3/zDJVKqeiSdeQ8ZBLuyQB9pBA79wedmOiMFpgIyNImZBdLYkwoHG2nU6RWrT4ptIGDF8UxbQgpWn5Qod7RMCAdITrRIDcfldQJ8VdJyaHSR4R9AqvUV4kCKeB2A4wXlYnEgMSdVjA6PGPBHvoaFwQck16V3uHzWok/KeEX9KgKmTOdfly2OT1hDv8rwNhILSKU1kmnTB3wel98s4iXP9TzbRiIdh1QqaNcaUEJiLVLJdJFEgz5g9HG96RMr39nmtRrsziU/NYVuocDh5UvuZKaEXPocn/opzIiVFdvx94bFcRbjDdJ6JlYGSKhjkmI7jjP5H3RrDqpwjAK98jmesDyhWSy4w/efbMSy3maiWVWg4HuY9Viu5/ym1wpRg3OLi4u4vtNRbJarTIiTJucmtx2/M6CEU2CBOOlzTmotmFSofdDSqy54w/koc8ex4tK0tGoQXgLgGHNPmKhyKAyPVjpeheEzzj1uM8Qk6LjLR05YpgNrPHPBCc9bHTru8rHTNwdi5JZvHIhoxPJ8tdNqh3CJc5/7mOUNa4UXTCvpYvM5/wCmvIrUfqsDYNhNldAj51fAnuUrYKLV6qjvnA+BbZZX7ALecCxbjavB+Rq4ZXkNrGrVHbjgHAiqIS6Djrt4Ap3lnKgh33oQIp9fPQiRIfAex6qlONacc1prjq/XsV5LxHucN6AN2FUq/7TVq0H8hmlbyC/2xUfWqegQtnnVhc+HAok8kGpNltU2w7TLC9lNCx53mVY3zxCb7dBxl5+owvHrfzHuMuwMI2pwLFVt6vf1v5jWEZdlkGIFjgesPJKyb9h+/S9GE24h7RyjCXF/Pen39L+ZBTLm8cu9b/H7X6rq+PT/ZtaqnGaddDn23m70/fpfGL7N5sBVtviNCErUF2Tx//N/p7kQTLocn5GIyJFCTgcxiW6LsmW6Q0RFhxS65xhpbyOmOstdsSfMKgwS23OWWaoeYpmwqv6KzvCti3/WQwDsYtRzgRiqrBL/8fRXF86+tgTHUZxrRGf7BmVZu5rks758pVKkqlv1v0oxzNLR/1Ped3G5aODB4rcvIk4UsD4nDYwHOKXg0DsMCpVUvpmm4gpe/h+YJSteCc7Fe5ZfVQ0KoXprlHXDqvsznf4O4ewmyecEHNdz1hBJL2uBn3DmnRV7MuPlB/Kq2BqU6yCCygPpZj44dzRobHHbHBw1BiQaGv37/2H6AiHsOcnlBfjP5ceF3eG0QRbjvlFsgijLgy8fAwxLC6tfHVy8ZTX7RSpvHTUryGR5eMj6cFXLw1fsVoJKlbfPdBdcWpAjyJE0xgQnFFn1e6kwL5yl3XFjQ5Z7jyQxuzhhxWrujxreEEeJB5Jj3oE8K+dMIWBb+8f/1bPAMfaeZOhXEYmFSNbOWYZo3OsV+gkxcnGMtaX0pi4icfOIpu5Raubi1N3foavRvMcx4pnS2hcRjW8GiGaQo5SMFUJVM1r0k5CxxlGPJqWytRCNXaYaIgpalEpuglC9Ml0ZH0fVc5Sc0UBUjTjr5e0tpbB3EUb4+sZ+jqoJHOMuKan+AFGJVrwu/aFBSZUEwrisBr6dzYMd8kQ4lEjNjrkZrmwjssGYEmnVEaqe+aovBYf1YEnxjSeIYRrSOy4xSef4FkI1rvDvP8p1vXdIW4Qerp5kh6ubp5j2AUIJZvsfz+tQwXHWoknRebcuYlkmSxoOZhTDqIdwneu6/f2nGSCEtWhRNGW/iHgGyUeJb02K5mGCE4KrCf4dkwsQRvRmDp1i7p9sxJVPMba94rfopOZdAadMru72/79mBeE630YmhRg/VhGf66Tb3zap5SiEt10JnNTLds+PJIcqTrHrpalJn2jOFtX09b4BEqksZmX6hDEq1S1EMLyi4P8P9u5EO00gCgPwHRRRQIOKRDGuaa02GmMS0//9n6x7T7cogzPMQO73Au0JCMNdT5l4yCBcPrffvX/p1OiLTjI5fNz3PeQlEiW1QyK+Gffm1y2HvnA613f+YxrU7dlOWhILFxLc0MXFUvqNE+JSIgwF7BqNVCYHgYI9XbbtwsZy41LroVgx/eFF4Cy+/lqNUagj/SlFTjavySiV2g0K5DYltkrpsHm74f98BfPaf39TFKnP33//uq2jMO/pbz4KNK1i41+ZDoIP9A9nhMJ41W79yW+GgvhGT6H1ObH/akYoROhcNLepUru+7PIBhVjp2ORryVzcktujCHcSe2WUizkBeIITQb+A/qvhoQB1q3b+2+cd9NtesP+8WrsebdSHbqJ16fhOG0dPVsakDs1Ses0a59g4dKxqBtBsqGaGv6UrEsuv5UIrr0GvqUX4F38BZFOaxPCpPPwjzrJx9HDFdELotKDXTSDByn3ElfAIjWI6ZYmzbFw/UDGJgD5d2YQkfwLKsGHG/2kTqRWD/AAwYg5tppffe1YuIauYGLps6bQDtHnTXeCSutBEJHRazYMmLpeBZTeBJg8SsxwVeyaWXQA9enTOAn/hIFBm9kcDRYfOmkILl6PAFtSGrZUs9LBxGX3VOHXo0KPzXvAHrgQ1YwkNRMvYP41KLADNwOqqgD6RqXeAy72AcnxocKQsEmjwQEzKAuqJJNfrh6cBmNCEekvK5iN+4TiwMSMot5VPR3MYyJgplLs2+AlS1U2g+qyh2pTI3Dvgrc6Dt6kopGuyJIkDwbKeodqCMruHajwSxngkKKLsunwDGLeHYnvK7haqcSBQ1gqKHUhCBPAZIA975wW5jtHb782vhZCWQq0bkjGEYjwXynQ+uEcyHBdqvSMm5wpqJXnjUDwYxIw6lJqSnCPUmhGTcg21uiTnBWrFxIyewu4MF6YLbguR04ZSoxpJ+gS13uZ2aGtyQRvjjyAuCZLjQSmfZDUFAD4ESLO0OTAhafdQiwfEGVwdEFjQncYT4mSszb+AD1Ar4oRgds06lPpA8hwB8/+Jt2oHpeqODdmINbGs1jb86R/xE7cHaqd3j+eW8njCdzwjJDtLRwS9t6NFXfAjIJtGBKU8+sp8JAApMYkggPFU7AA/cF1QoWox1OpZ06IecHV4Bjsodm1JPJoLg8wsDruivEKo5nJG4Kw2FFvZtMBqyQHhM1ohFNtZtbhgSyxrJYjxzuwh1BP8JZA5B2d8SnsLGkQ8KuCETgTVBpRfBA3WfAx4XQrlfOvWmHJ5YKEre0KfcmoM8INF92S1PUCHTYfyaC2hh8cTo17j3ECHaEjydh70CF6IFb0spr8gOUkKTfodYid8FNBBDBLKrvPoQpMZ54POGLrQov78nrLpdEP8jYvDizMJoIe4GTborNuVC11CnhibhfMMXUb7eY1OmLTvoc+UJwVl5NehTZgeJ/Q/reE4gE57fv1ntoihU7jc9w6LFn3XTO78x00MvdwdseycTwLaiTAcXY0EinDPJcGS7mJUhxjz41+aMxaoiGBBLId5NR4C9TYngHNqbEOU3pJ//hfoDEr+HvB6/PO/zO09yksMeDzcxWr+FUpqzd9+SjSOHkoo4Mi/Mk67dKfBK375K9V5LNUtcOXz5VetuY1QEtGRA386NPwAJRB/5A1B2gwfYLn+gZhOk/EI1hLpHTHdnN4UVrrqJsQKcbu37jFQTw988C9Q7cPMhT3iNjf9Fq7p39iRKYoG3PRvSHLsC5jl7ef86Deps0tdmBKtPvDVN69xGMQonFi2udTDHom/8VAcb7bjJk/rLLapB/2iWY/z/Na69veBgDbxs8/9XdZrPm1n6u+CeLN94gKv8mjc9gYPHlQYLVd87Uuqebvrzu5HyMcN1p96c47xlZ/z/oPfXa2DqI7zhBc8bMbH4YLP+RXkJIund712ezxePac3/W/SNN2sBuP2tucP5xO+7IwxxhhjjH1uDw4JAAAAAAT9f+0LEwAAAAAAAAAAAAAAAAAAAAAAAPwCWFpd4wSUd0QAAAAASUVORK5CYII=">
  <style type="text/css">
    body {
      font-size: 16px;
      background: #fff;
      font-family: Menlo, Consolas, Roboto Mono, Ubuntu Monospace, Oxygen Mono, Liberation Mono, monospace;
      min-width: 320px;
      text-align: center;
      margin: 1rem 0 0;
    }

    section {
      display: inline-block;
      background: #fff url('data:image/png;base64,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') left center no-repeat;
      background-size: 5rem;
      padding-left: 6rem;
    }

    .line {
      color: #333;
      text-align: center;
      border-top: 1px dashed #333;
      padding: .6rem .5rem 0;
    }
  </style>
  <title>${1} ${2}</title>
</head>
<body>
<section>
  <div style="font-size: 5rem">${1}</div>
  <div class="line">${2}</div>
</section>
</body>
</html>
EOF
}

run "Создание страниц ошибок"
  page 401 "Unauthorized" && \
  page 403 "Forbidden" && \
  page 404 "Not Found" && \
  page 500 "Internal Server Error" && \
  page 502 "Bad Gateway" && \
  page 503 "Service Unavailable"
check

run "Создание файла ${domain}.conf"
cat > "${project}/web/nginx/conf.d/${domain}.conf" << EOF
server {
    listen 80;
    listen 443 ssl http2;
    server_name ${domain} www.${domain};

     # Путь по которому certbot сможет проверить сервер на подлинность
    location /.well-known/acme-challenge/ { root /var/www/certbot; }

    # Настройка SSL
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    ssl_stapling on;
    ssl_buffer_size 8k;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    add_header Strict-Transport-Security 'max-age=604800';

    # Замена стандартных страниц ошибок Nginx
    include /etc/nginx/errand/errand.inc;

    # Настройка логирования
    error_log /var/log/nginx/${domain}/error.log warn;
    access_log /var/log/nginx/${domain}/access.log;

    # Редирект с www и http
    if (\$server_port = 80) { set \$https_redirect 1; }
    if (\$host ~ '^www\.') { set \$https_redirect 1; }
    if (\$https_redirect = 1) { return 301 https://\$host\$request_uri; }

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

run "Создание docker-compose.yml для Nginx и CertBot"
cat > "${project}/web/docker-compose.yml" << EOF
version: "3.7"
services:

  nginx:
    image: nginx
    container_name: nginx
    restart: always
    command: "/bin/sh -c 'while :; do sleep 6h & wait \$\${!}; nginx -s reload; done & nginx -g \\"daemon off;\\"'"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf    # Базовая конфигураци
      - ./nginx/conf.d:/etc/nginx/conf.d            # Пользовательские конфигурации
      - ./nginx/errand:/etc/nginx/errand            # Пользовательские страницы ошибок
      - ./nginx/ssl:/etc/nginx/ssl                  # Фиктивный SSL для базовых настроек
      - ./nginx/log:/var/log/nginx                  # Логи NGINX
      - ./certbot/conf:/etc/letsencrypt             # Сертификаты Let’s Encrypt
      - ./certbot/www:/var/www/certbot              # Файлы проверки Let’s Encrypt

  certbot:
    image: certbot/certbot
    container_name: certbot
    restart: always
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"
    volumes:
      - ./certbot/log:/var/log/letsencrypt          # Логи CertBot Let’s Encrypt
      - ./certbot/conf:/etc/letsencrypt             # Сертификаты Let’s Encrypt
      - ./certbot/www:/var/www/certbot              # Файлы проверки Let’s Encrypt

networks:
  default:
    name: app
EOF
check

certbot_url="https://raw.githubusercontent.com/certbot/certbot/master"

run "Создание директорий и файлов для CertBot"
  mkdir -p ${project}/web/certbot/log && \
  mkdir -p ${project}/web/certbot/conf/live/${domain} && \
  mkdir -p ${project}/web/certbot/www && \
  curl -s ${certbot_url}/certbot-nginx/certbot_nginx/tls_configs/options-ssl-nginx.conf > "${project}/web/certbot/conf/options-ssl-nginx.conf" && \
  curl -s ${certbot_url}/certbot/ssl-dhparams.pem > "${project}/web/certbot/conf/ssl-dhparams.pem"
check

run "Генерация self-signed SSL certificate"
  sed -i "/RANDFILE\ /d" /etc/ssl/openssl.cnf && \
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ${project}/web/nginx/ssl/privkey.pem -out ${project}/web/nginx/ssl/fullchain.pem -subj "/C=RU/ST=/L=/O=/OU=/CN=" && \
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ${project}/web/certbot/conf/live/${domain}/privkey.pem -out ${project}/web/certbot/conf/live/${domain}/fullchain.pem -subj "/C=RU/ST=/L=/O=/OU=/CN=${domain}"
check

run "Изменение владельца и группы созданных файлов"
  chown -R ${username}:${username} ${project}
check

run "Загрузка используемых образов Docker"
  docker pull mysql && \
  docker pull phpmyadmin/phpmyadmin && \
  docker pull nginx && \
  docker pull certbot/certbot
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
