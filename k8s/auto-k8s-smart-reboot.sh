#!/bin/bash

set -e

# Configuration
LOG="/var/log/auto_k8s_maintenance.log"
KUBECONFIG="/root/.kube/config"
BACKUP_DIR="/opt/k8s-backup"
ERR=0

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ОШИБКА: $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ОШИБКА: $1" >> "$LOG"
}

warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ПРЕДУПРЕЖДЕНИЕ: $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ПРЕДУПРЕЖДЕНИЕ: $1" >> "$LOG"
}

run() {
    log "Executing: $*"
    "$@" 2>>"$LOG"
    local status=$?
    if [ $status -ne 0 ]; then
        error "Command failed: $*"
        ERR=1
    else
        log "Command succeeded: $*"
    fi
    return $status
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Скрипт должен запускаться от root"
   exit 1
fi

log "Начинаю процесс обслуживания и перезагрузки K8s..."

# 0. Предварительные проверки
log "Выполняю предварительные проверки..."
if ! kubectl cluster-info &> /dev/null; then
    error "Не удается подключиться к кластеру Kubernetes"
    exit 1
fi

# 1. Создание бэкапа перед обслуживанием
log "Создаю бэкап перед обслуживанием..."
mkdir -p "$BACKUP_DIR"
kubectl get all -A -o yaml > "$BACKUP_DIR/pre-maintenance-backup-$(date +%Y%m%d_%H%M%S).yaml"

# 2. Безопасный drain ноды
log "Выполняю drain ноды $(hostname)..."
run kubectl drain "$(hostname)" --ignore-daemonsets --delete-emptydir-data --force --kubeconfig="$KUBECONFIG" --timeout=300s

# 3. Обновление системных пакетов
log "Обновляю системные пакеты..."
run apt update
run apt -y upgrade
run apt -y autoremove

# 4. Обновление компонентов Kubernetes
log "Обновляю компоненты Kubernetes..."
run apt -y install --only-upgrade kubeadm kubelet kubectl containerd

# 5. Перезапуск критических сервисов
log "Перезапускаю критические сервисы..."
run systemctl restart containerd
run systemctl restart kubelet

# 6. Перезапуск VPN сервисов
log "Перезапускаю VPN сервисы..."
run kubectl rollout restart deployment/xray -n vpn --kubeconfig="$KUBECONFIG"
run kubectl rollout restart deployment/nginx -n vpn --kubeconfig="$KUBECONFIG"

# 7. Ожидание завершения rollouts
log "Ожидаю завершения rollouts..."
run kubectl rollout status deployment/xray -n vpn --timeout=300s --kubeconfig="$KUBECONFIG"
run kubectl rollout status deployment/nginx -n vpn --timeout=300s --kubeconfig="$KUBECONFIG"

# 8. Финальная проверка здоровья
log "Выполняю финальную проверку здоровья..."
if kubectl get pods -n vpn --no-headers | grep -v "Running" | grep -v "Completed"; then
    warning "Некоторые VPN поды не в состоянии Running"
else
    log "Все VPN поды работают"
fi

# 9. Перезагрузка если все ОК
if [ $ERR -eq 0 ]; then
    log "Все операции завершены успешно. Перезагружаю через 30 секунд..."
    sleep 30
    /sbin/reboot
else
    error "Обслуживание не удалось. Проверьте $LOG для деталей. Перезагрузка не выполняется."
    exit 1
fi
