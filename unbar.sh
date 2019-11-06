#!/usr/bin/env bash

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
port_ssh=$(shuf -i 50000-55000 -n 1)
port_sql=$(shuf -i 55001-60000 -n 1)

echo -en "\n${cyan}Введите имя нового пользователя: ${end}"; read username
echo -en "${cyan}Введите пароль нового пользователя: ${end}"; read -r password
echo -en "${cyan}Введите домен для PhpMyAdmin: ${end}"; read domain_pma
echo -en "${cyan}Введите домен для DockerRegistry: ${end}"; read domain_rep

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
  ufw allow ${port_ssh} && \
  ufw allow ${port_sql}
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
  sed -i "/^Port/s/^/# /" /etc/ssh/sshd_config && \
  sed -i "/^PermitRootLogin/s/^/# /" /etc/ssh/sshd_config && \
  sed -i "/^AllowUsers/s/^/# /" /etc/ssh/sshd_config && \
  sed -i "/^PermitEmptyPasswords/s/^/# /" /etc/ssh/sshd_config && \
  {
    echo -e "\n# unbar.sh"
    echo "Port ${port_ssh}"
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

# === СОЗДАНИЕ СТРУКТУРЫ СЕРВЕРА === #

project="/home/${username}/app"

run "Клонирование репозитория UNBAR.SH"
  git clone https://github.com/goodvir/unbar.sh /tmp/unbar
check

run "Копирование папки проекта"
  cp -R "/tmp/unbar/app" ${project}
check

run "Замена переменных в db/docker-compose.yml"
  sed -i "s/[PASSWORD]/${password}/g" ${project}/db/docker-compose.yml && \
  sed -i "s/[PORT_SQL]/${port_sql}/g" ${project}/db/docker-compose.yml && \
  sed -i "s/[DOMAIN_PMA]/${domain_pma}/g" ${project}/db/docker-compose.yml
check

run "Настройка конфигурации ${domain_pma}.conf"
  sed -i "s/[DOMAIN_PMA]/${domain_pma}/g" ${project}/web/nginx/conf.d/pma.conf && \
  mv ${project}/web/nginx/conf.d/pma.conf ${project}/web/nginx/conf.d/${domain_pma}.conf && \
  mkdir -p ${project}/web/nginx/log/${domain_pma}
check

run "Настройка конфигурации ${domain_rep}.conf"
  sed -i "s/[DOMAIN_REP]/${domain_rep}/g" ${project}/web/nginx/conf.d/rep.conf && \
  mv ${project}/web/nginx/conf.d/rep.conf ${project}/web/nginx/conf.d/${domain_rep}.conf && \
  mkdir -p ${project}/web/nginx/log/${domain_rep}
check

certbot_url="https://raw.githubusercontent.com/certbot/certbot/master"

run "Создание директорий и файлов для CertBot"
  mkdir -p ${project}/web/certbot/log && \
  mkdir -p ${project}/web/certbot/conf/live/${domain_pma} && \
  mkdir -p ${project}/web/certbot/conf/live/${domain_rep} && \
  mkdir -p ${project}/web/certbot/www && \
  curl -s ${certbot_url}/certbot-nginx/certbot_nginx/tls_configs/options-ssl-nginx.conf > "${project}/web/certbot/conf/options-ssl-nginx.conf" && \
  curl -s ${certbot_url}/certbot/ssl-dhparams.pem > "${project}/web/certbot/conf/ssl-dhparams.pem"
check

run "Генерация self-signed SSL certificate"
  sed -i "/^RANDFILE/s/^/# /" "/etc/ssl/openssl.cnf" && \
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ${project}/web/nginx/ssl/privkey.pem -out ${project}/web/nginx/ssl/fullchain.pem -subj "/C=RU" && \
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ${project}/web/certbot/conf/live/${domain_pma}/privkey.pem -out ${project}/web/certbot/conf/live/${domain_pma}/fullchain.pem -subj "/C=RU/CN=${domain_pma}" && \
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout ${project}/web/certbot/conf/live/${domain_rep}/privkey.pem -out ${project}/web/certbot/conf/live/${domain_rep}/fullchain.pem -subj "/C=RU/CN=${domain_rep}"
check

run "Изменение владельца и группы созданных файлов"
  chown -R ${username}:${username} ${project}
check

run "Загрузка используемых образов Docker"
  docker pull mysql && \
  docker pull phpmyadmin/phpmyadmin && \
  docker pull nginx && \
  docker pull certbot/certbot && \
  docker pull registry
check

# === ДОБАВЛЕНИЕ СКРИПТА ПЕРВОГО ЗАПУСКА В АВТОЗАГРУЗКУ === #

# todo run.sh

# === ОЧИСТКА ПЕРЕД ЗАВЕРШЕНИЕМ === #

run "Очистка пакетного менеджера"
  apt autoremove -y && \
  apt autoclean -y
check

# === ЗАВЕРШЕНИЕ РАБОТЫ СКРИПТА === #

ip=$(wget -qO- ifconfig.co)

echo -e "${clr}${clr}${clr}${clr}${clr}${clr}${end}"

echo -e "${green}  Пользователь: ${cyan}${username}${end}"
echo -e "${green}        Пароль: ${cyan}${password}${end}"
echo -e "${green}      Порт SSH: ${cyan}${port_ssh}${end}"
echo -e "${green}      Порт SQL: ${cyan}${port_sql}${end}"
echo -e "${green}    Внешний IP: ${cyan}${ip}${end}"

echo -e "\n${cyan}ssh ${username}@${ip} -p ${port_ssh}${end}"
echo -e "${cyan}sh://${username}@${ip}:${port_ssh}/${end}"
echo -e "\n${cyan}https://${domain_pma}${end}"
echo -e "${cyan}https://${domain_rep}${end}"

echo -e "${clr}${clr}${clr}${clr}${clr}${clr}${end}"

echo -e "\n${red}[ВНИМАНИЕ] Система будет перезагружена!${end}"
echo -e "${red}Сохраните данные указанные выше!${end}\n"

close "reboot"

# todo logrotate поставить настроить
# todo Отключить логи докера по умолчанию
