#!/bin/bash

set -e

# Функции логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ОШИБКА: $1"
}

# Конфигурация
BACKUP_DIR="/opt/k8s-backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="k8s-backup-$DATE"

log "Начинаю резервное копирование K8s Single-Node Infrastructure..."

# Создание директории для бэкапов
mkdir -p "$BACKUP_DIR"

# 1. Бэкап ресурсов Kubernetes
log "Создаю бэкап ресурсов Kubernetes..."
kubectl get all -A -o yaml > "$BACKUP_DIR/$BACKUP_NAME-resources.yaml"
kubectl get configmaps -A -o yaml > "$BACKUP_DIR/$BACKUP_NAME-configmaps.yaml"
kubectl get secrets -A -o yaml > "$BACKUP_DIR/$BACKUP_NAME-secrets.yaml"

# 2. Бэкап persistent volumes
log "Создаю бэкап persistent volumes..."
kubectl get pv -o yaml > "$BACKUP_DIR/$BACKUP_NAME-persistent-volumes.yaml"
kubectl get pvc -A -o yaml > "$BACKUP_DIR/$BACKUP_NAME-persistent-volume-claims.yaml"

# 3. Бэкап конфигурации кластера
log "Создаю бэкап конфигурации кластера..."
cp /etc/kubernetes/admin.conf "$BACKUP_DIR/$BACKUP_NAME-admin.conf"
cp /etc/kubernetes/kubelet.conf "$BACKUP_DIR/$BACKUP_NAME-kubelet.conf"

# 4. Бэкап systemd сервисов
log "Создаю бэкап systemd сервисов..."
cp /etc/systemd/system/k8s-uncordon.service "$BACKUP_DIR/$BACKUP_NAME-uncordon.service" 2>/dev/null || true

# 5. Бэкап скриптов
log "Создаю бэкап скриптов..."
cp /usr/local/bin/k8s-uncordon.sh "$BACKUP_DIR/$BACKUP_NAME-uncordon.sh" 2>/dev/null || true
cp /usr/local/bin/auto-k8s-smart-reboot.sh "$BACKUP_DIR/$BACKUP_NAME-reboot.sh" 2>/dev/null || true

# 6. Создание архива
log "Создаю архив бэкапа..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"*
rm -rf "$BACKUP_NAME"*

# 7. Очистка старых бэкапов (оставляем за последние 7 дней)
log "Очищаю старые бэкапы..."
find "$BACKUP_DIR" -name "k8s-backup-*.tar.gz" -mtime +7 -delete

log "Резервное копирование завершено успешно!"
echo "Расположение бэкапа: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Размер бэкапа: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)" 