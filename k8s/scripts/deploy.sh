#!/bin/bash

set -e

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ОШИБКА: $1"
}

# Проверка доступности kubectl
if ! command -v kubectl &> /dev/null; then
    error "kubectl не установлен или не найден в PATH"
    exit 1
fi

# Проверка доступности кластера
if ! kubectl cluster-info &> /dev/null; then
    error "Не удается подключиться к кластеру Kubernetes"
    exit 1
fi

log "Начинаю деплой K8s Single-Node Infrastructure..."

# 1. Создание namespace
log "Создаю namespace..."
kubectl apply -f k8s/namespaces/

# 2. Деплой VPN компонентов
log "Деплой XRay VPN..."
kubectl apply -f k8s/xray/

log "Деплой Nginx reverse proxy..."
kubectl apply -f k8s/nginx/

# 3. Ожидание готовности подов
log "Ожидаю готовности подов..."
kubectl wait --for=condition=Ready pods -l app=xray -n vpn --timeout=300s
kubectl wait --for=condition=Ready pods -l app=nginx -n vpn --timeout=300s

# 4. Деплой мониторинга (если еще не развернут)
if ! kubectl get namespace monitoring &> /dev/null; then
    log "Деплой стека мониторинга..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install kube-prometheus prometheus-community/kube-prometheus-stack \
      -n monitoring --create-namespace \
      -f k8s/monitoring-light.yaml
else
    log "Стек мониторинга уже существует, пропускаю..."
fi

# 5. Показать статус деплоя
log "Деплой завершен! Текущий статус:"
echo ""
echo "=== Поды ==="
kubectl get pods -A
echo ""
echo "=== Сервисы ==="
kubectl get svc -A
echo ""
echo "=== NodePort сервисы ==="
kubectl get svc -A -o wide | grep NodePort

# 6. Показать информацию о доступе
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
GRAFANA_PORT=$(kubectl get svc -n monitoring kube-prometheus-grafana -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")

echo ""
log "Информация о доступе:"
echo "• Nginx HTTP:  http://$NODE_IP:30080"
echo "• XRay VPN:    $NODE_IP:30443"
echo "• Grafana:     http://$NODE_IP:$GRAFANA_PORT"
echo ""
echo "Данные для входа в Grafana:"
echo "• Логин: admin"
echo "• Пароль: prom-operator" 