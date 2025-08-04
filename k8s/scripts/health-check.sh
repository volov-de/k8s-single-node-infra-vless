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

info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ИНФО: $1"
}

# Проверка доступности kubectl
if ! command -v kubectl &> /dev/null; then
    error "kubectl не установлен или не найден в PATH"
    exit 1
fi

log "Начинаю проверку здоровья K8s Single-Node Infrastructure..."

# 1. Проверка статуса кластера
echo ""
info "=== Статус кластера ==="
kubectl cluster-info
kubectl get nodes -o wide

# 2. Проверка всех подов
echo ""
info "=== Статус подов ==="
kubectl get pods -A

# 3. Проверка сервисов
echo ""
info "=== Статус сервисов ==="
kubectl get svc -A

# 4. Проверка упавших подов
echo ""
info "=== Упавшие поды ==="
FAILED_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | grep -v "No resources found" || true)
if [ -n "$FAILED_PODS" ]; then
    error "Найдены упавшие поды:"
    echo "$FAILED_PODS"
else
    log "Упавших подов не найдено"
fi

# 5. Проверка использования ресурсов
echo ""
info "=== Использование ресурсов ==="
kubectl top nodes 2>/dev/null || warning "Сервер метрик недоступен"
kubectl top pods -A 2>/dev/null || warning "Сервер метрик недоступен"

# 6. Проверка системных ресурсов
echo ""
info "=== Системные ресурсы ==="
echo "Использование CPU:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
echo "Использование памяти:"
free -h | grep Mem | awk '{print $3"/"$2" ("$3/$2*100.0"%")"}'
echo "Использование диска:"
df -h / | tail -1 | awk '{print $5}'

# 7. Проверка конкретных сервисов
echo ""
info "=== Статус VPN сервисов ==="
if kubectl get pods -n vpn -l app=xray &> /dev/null; then
    XRAY_STATUS=$(kubectl get pods -n vpn -l app=xray -o jsonpath='{.items[0].status.phase}')
    if [ "$XRAY_STATUS" = "Running" ]; then
        log "XRay VPN работает"
    else
        error "XRay VPN не работает (Статус: $XRAY_STATUS)"
    fi
else
    warning "XRay VPN не найден"
fi

if kubectl get pods -n vpn -l app=nginx &> /dev/null; then
    NGINX_STATUS=$(kubectl get pods -n vpn -l app=nginx -o jsonpath='{.items[0].status.phase}')
    if [ "$NGINX_STATUS" = "Running" ]; then
        log "Nginx reverse proxy работает"
    else
        error "Nginx reverse proxy не работает (Статус: $NGINX_STATUS)"
    fi
else
    warning "Nginx reverse proxy не найден"
fi

# 8. Проверка мониторинга
echo ""
info "=== Статус мониторинга ==="
if kubectl get namespace monitoring &> /dev/null; then
    MONITORING_PODS=$(kubectl get pods -n monitoring --no-headers | wc -l)
    if [ "$MONITORING_PODS" -gt 0 ]; then
        log "Стек мониторинга развернут ($MONITORING_PODS подов)"
    else
        warning "Namespace мониторинга существует, но поды не найдены"
    fi
else
    warning "Namespace мониторинга не найден"
fi

# 9. Проверка systemd сервисов
echo ""
info "=== Systemd сервисы ==="
if systemctl is-active --quiet k8s-uncordon.service; then
    log "k8s-uncordon.service активен"
else
    warning "k8s-uncordon.service не активен"
fi

# 10. Проверка логов на ошибки
echo ""
info "=== Последние ошибки (последние 10 строк) ==="
kubectl get events --sort-by='.lastTimestamp' | tail -10

log "Проверка здоровья завершена!" 