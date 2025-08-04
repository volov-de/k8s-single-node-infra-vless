# Скрипт для генерации уникальных параметров и конфигов XRAY
# Использование: ./generate-xray-config.sh <dns_address>

set -e

# Генерация UUID для id
ID=$(cat /proc/sys/kernel/random/uuid)

# Генерация приватного ключа (32 символа base64)
PRIVATE_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '=+/')

# Генерация shortId (8 цифр)
SHORT_ID=$(shuf -i 10000000-99999999 -n 1)

# DNS по умолчанию
DEFAULT_DNS="tls://1.1.1.1"
DNS_ADDRESS=${1:-$DEFAULT_DNS}

# Папка со скриптом
DIR=$(dirname "$0")

# Сохраняем параметры в env-файл
cat <<EOF > "$DIR/xray-params.env"
ID="$ID"
PRIVATE_KEY="$PRIVATE_KEY"
SHORT_ID="$SHORT_ID"
DNS_ADDRESS="$DNS_ADDRESS"
EOF

# Генерируем итоговый конфиг XRAY для деплоя
envsubst < "$DIR/xray-configmap.yaml" > "$DIR/xray-configmap.generated.yaml"

# Инструкция для подключения
echo "\nПараметры XRAY VPN сгенерированы:"
echo "ID: $ID"
echo "PRIVATE_KEY: $PRIVATE_KEY"
echo "SHORT_ID: $SHORT_ID"
echo "DNS_ADDRESS: $DNS_ADDRESS"
echo "\nСсылка для подключения (пример):"
echo "vless://$ID@<SERVER_IP>:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=$PRIVATE_KEY&sid=$SHORT_ID&type=tcp&flow=xtls-rprx-vision#XRAY-VPN"
echo "\nДля деплоя используйте файл xray-configmap.generated.yaml"
