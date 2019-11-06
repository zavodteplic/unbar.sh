#!/usr/bin/env bash

# Цветной текст
red="\e[31m"
green="\e[32m"
brown="\e[33m"
blue="\e[34m"
purple="\e[35m"
cyan="\e[36m"

# Завершение вывода цвета
end="\e[0m"

function run() {
  # Печать информации о выполнении новой команды
  echo -e "${brown}${1}${end}"
}

function answer() {
  # Соглашение пользователя на продолжение
  temp=""
  read temp
  temp=$(echo ${temp^^})
  echo -e "${end}"
  if [[ "${temp}" != "Y" && "${temp}" != "YES" ]]; then return 255; fi
}

function close() {
  # Завершение работы скрипта
  echo -en "${brown}Нажмите любую клавишу, чтобы продолжить...${end}"
  read -s -n 1
  clear
  exit 0
}

# Вывод информации о скрипте
clear
clr=$(echo -e "${red}*${green}*${brown}*${blue}*${purple}*${cyan}*${brown}")
echo -en "${brown}"
echo "   ${clr}  CertBot Let’s Encrypt  ${clr}"
echo "Генерация доверенных сертификатов UNBAR.SH"
echo -en "${end}\n"

# Подготовка данных
echo -en "${cyan}Введите домен [domain.ru]: ${end}"; read domain
echo -en "${cyan}Введите email [name@mail.ru]: ${end}"; read email
echo -en "${cyan}Отключить режим тестирования [Y/n]: ${end}"; read staging

regex="([^www.].+)"

# Проверка www в домене
domain=`echo ${domain} | grep -o -P ${regex}`

# Проверка наличия email
case "${email}" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Проверка режима тестирования
if [[ ${staging} != "Y" ]]; then staging_arg="--staging"; fi

# Запрос разрешения на запуск скрипта
echo -en "\n${green}Подтвердите запуск скрипта [Y/n]: ${end}"
answer; if [[ $? -ne 0 ]]; then close; fi

run "Остановка docker-compose.yml"
docker-compose down
echo

# Генерация фиктивных сертификатов при их отсутствии
mkdir -p "./certbot/conf/live/${domain}"
if [[ ! -e "./certbot/conf/live/${domain}/privkey.pem" && ! -e "./certbot/conf/live/${domain}/fullchain.pem" ]]; then
  run "Генерация фиктивных сертификатов для запуска nginx"
  docker-compose run --rm --entrypoint "openssl req -x509 -nodes -newkey rsa:1024 -days 1 -keyout '/etc/letsencrypt/live/${domain}/privkey.pem' -out '/etc/letsencrypt/live/${domain}/fullchain.pem' -subj '/CN=localhost'" certbot
  echo
fi

run "Запуск nginx"
docker-compose up --force-recreate -d nginx
echo

run "Очистка старых сертификатов"
docker-compose run --rm --entrypoint "rm -Rf /etc/letsencrypt/live/${domain} && rm -Rf /etc/letsencrypt/archive/${domain} && rm -Rf /etc/letsencrypt/renewal/${domain}.conf" certbot
echo

certbot_args="certbot certonly --webroot -w /var/www/certbot ${staging_arg} ${email_arg} --cert-name ${domain} -d ${domain} --rsa-key-size 4096 --agree-tos --force-renewal"

run "Параметры запроса сертификата Let's Encrypt"
echo ${certbot_args}
echo

run "Запрос сертификата Let's Encrypt для ${domain}"
docker-compose run --rm --entrypoint "${certbot_args}" certbot
echo

run "Перезагрузка docker-compose.yml"
docker-compose down
echo
docker-compose up -d
echo

close
