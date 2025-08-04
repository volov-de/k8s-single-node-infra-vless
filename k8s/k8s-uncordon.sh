#!/bin/bash

set -e

# Configuration
KUBECONFIG="/root/.kube/config"
LOG="/var/log/k8s_uncordon.log"
MAX_ATTEMPTS=36      # до 6 минут (по 10 сек попытка)
ATTEMPT=1

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

# Получение имени ноды динамически
NODE_NAME=$(hostname)

log "Начинаю процесс uncordon для ноды: $NODE_NAME"

# Ожидание готовности сети
log "Ожидаю готовности сети..."
sleep 10

while (( $ATTEMPT <= $MAX_ATTEMPTS )); do
    log "Попытка $ATTEMPT/$MAX_ATTEMPTS - Проверяю Kubernetes API..."
    
    if kubectl get nodes --kubeconfig="$KUBECONFIG" > /dev/null 2>&1; then
        log "Kubernetes API сервер доступен, пытаюсь uncordon..."
        
        if kubectl uncordon "$NODE_NAME" --kubeconfig="$KUBECONFIG" >> "$LOG" 2>&1; then
            log "УСПЕХ: Нода $NODE_NAME успешно uncordoned"
            
            # Проверка успешности uncordon
            if kubectl get node "$NODE_NAME" --kubeconfig="$KUBECONFIG" -o jsonpath='{.spec.unschedulable}' | grep -q "false"; then
                log "Проверка uncordon ноды успешна"
                exit 0
            else
                warning "Проверка uncordon ноды не удалась, повторяю..."
            fi
        else
            error "Uncordon не удался, повторяю через 10 секунд..."
        fi
    else
        warning "API сервер не готов (попытка $ATTEMPT/$MAX_ATTEMPTS)..."
    fi
    
    ATTEMPT=$((ATTEMPT+1))
    sleep 10
done

error "КРИТИЧЕСКАЯ ОШИБКА: Uncordon ноды не удался после $MAX_ATTEMPTS попыток"
exit 1
