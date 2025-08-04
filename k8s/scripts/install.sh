#!/bin/bash

set -e

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ОШИБКА: $1"
}

warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ПРЕДУПРЕЖДЕНИЕ: $1"
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Скрипт должен запускаться от root"
   exit 1
fi

log "Начинаю установку K8s Single-Node Infrastructure..."

# 1. Обновление системы
log "Обновляю пакеты системы..."
apt update && apt upgrade -y

# 2. Установка зависимостей
log "Устанавливаю зависимости..."
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 3. Установка containerd
log "Устанавливаю containerd..."
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# 4. Добавление репозитория Kubernetes
log "Добавляю репозиторий Kubernetes..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/share/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# 5. Установка компонентов Kubernetes
log "Устанавливаю компоненты Kubernetes..."
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 6. Инициализация кластера
log "Инициализирую кластер Kubernetes..."
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# 7. Настройка kubectl
log "Настраиваю kubectl..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 8. Установка Flannel
log "Устанавливаю сетевой плагин Flannel..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 9. Ожидание готовности кластера
log "Ожидаю готовности кластера..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# 10. Установка Helm
log "Устанавливаю Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
apt update
apt install -y helm

# 11. Создание namespace
log "Создаю namespace..."
kubectl apply -f k8s/namespaces/

# 12. Деплой VPN компонентов
log "Деплой VPN компонентов..."
kubectl apply -f k8s/xray/
kubectl apply -f k8s/nginx/

# 13. Деплой мониторинга
log "Деплой стека мониторинга..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f k8s/monitoring-light.yaml

# 14. Настройка systemd сервиса
log "Настраиваю systemd сервис..."
cp k8s/systemd/k8s-uncordon.service /etc/systemd/system/
cp k8s/k8s-uncordon.sh /usr/local/bin/
chmod +x /usr/local/bin/k8s-uncordon.sh
systemctl daemon-reload
systemctl enable k8s-uncordon.service

# 15. Настройка скрипта обслуживания
log "Настраиваю скрипт обслуживания..."
cp k8s/auto-k8s-smart-reboot.sh /usr/local/bin/
chmod +x /usr/local/bin/auto-k8s-smart-reboot.sh

log "Установка завершена успешно!"
log "Статус кластера:"
kubectl get nodes
kubectl get pods -A

echo ""
log "Следующие шаги:"
echo "1. Обновить конфигурацию клиента XRay"
echo "2. Протестировать VPN подключение"
echo "3. Открыть Grafana: http://$(hostname -I | awk '{print $1}'):$(kubectl get svc -n monitoring kube-prometheus-grafana -o jsonpath='{.spec.ports[0].nodePort}')" 