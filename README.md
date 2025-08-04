# K8s Single-Node DevOps Playground

**Production-ready** pet-проект, демонстрирующий практический опыт с Kubernetes, Helm, инфраструктурной автоматизацией и безопасным прокси/VPN. Всё развёрнуто на **одиночном сервере** через `kubeadm`, включая:

- VPN-сервер (XRay/vless с Reality)
- Nginx reverse proxy
- Monitoring stack (Prometheus + Grafana)
- Zero-downtime auto-reboot
- SSH-only доступ, GitOps подход
- Безопасность и мониторинг

>  Этот проект — мой персональный mini-devops-инфраструктурный кластер.

---

## Структура проекта

```
k8s-single-node-infra-vless/
├── k8s/
│   ├── xray/                    # VPN компоненты
│   │   ├── xray-configmap.yaml
│   │   ├── xray-deployment.yaml
│   │   └── xray-service.yaml
│   ├── nginx/                   # Reverse proxy
│   │   ├── nginx-configmap.yaml
│   │   ├── nginx-deployment.yaml
│   │   └── nginx-service.yaml
│   ├── namespaces/              # Namespaces
│   │   └── vpn-namespace.yaml
│   ├── systemd/                 # Systemd сервисы
│   │   └── k8s-uncordon.service
│   ├── scripts/                 # Автоматизация
│   │   ├── install.sh          # Полная установка
│   │   ├── deploy.sh           # Быстрый деплой
│   │   ├── backup.sh           # Резервное копирование
│   │   └── health-check.sh     # Проверка здоровья
│   ├── auto-k8s-smart-reboot.sh # Zero-downtime обновления
│   ├── k8s-uncordon.sh         # Автоматический uncordon
│   └── monitoring-light.yaml    # Конфигурация мониторинга
├── screenshots/                 # Скриншоты работы
└── README.md                   # Документация
```

---

## Цели проекта

- Освоить **production-like окружение** на минимальной инфраструктуре
- Научиться **разворачивать, мониторить и поддерживать сервисы** в Kubernetes
- Реализовать **автоматизацию обслуживания без простоев**
- Получить работающий кейс для портфолио

---

## Стек технологий

| Категория           | Технологии                                    |
|---------------------|-----------------------------------------------|
| Контейнеризация     | `Docker`, `containerd`                        |
| Оркестрация         | `Kubernetes (kubeadm)`                        |
| VPN/Proxy           | `XRay`, `vless`, `nginx`                      |
| Monitoring          | `Prometheus`, `Grafana`, `kube-state-metrics`|
| CI/Automation       | `bash`, `systemd`, `Helm`                     |
| Security            | `iptables`, `SSH-only`, `TLS termination`     |

---

## Быстрый старт

### 1. Полная установка (рекомендуется)

```bash
# Клонировать репозиторий
git clone https://github.com/volov_de/k8s-single-node-infra-vless.git
cd k8s-single-node-infra-vless

# Запустить полную установку
sudo chmod +x k8s/scripts/install.sh
sudo ./k8s/scripts/install.sh
```

### 2. Быстрый деплой (если K8s уже установлен)

```bash
# Деплой компонентов
sudo chmod +x k8s/scripts/deploy.sh
./k8s/scripts/deploy.sh
```

### 3. Ручная установка

```bash
# 1. Создать namespace
kubectl apply -f k8s/namespaces/

# 2. Деплой VPN компонентов
kubectl apply -f k8s/xray/
kubectl apply -f k8s/nginx/

# 3. Деплой мониторинга
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f k8s/monitoring-light.yaml

# 4. Настройка systemd сервиса
sudo cp k8s/systemd/k8s-uncordon.service /etc/systemd/system/
sudo cp k8s/k8s-uncordon.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/k8s-uncordon.sh
sudo systemctl daemon-reload
sudo systemctl enable k8s-uncordon.service
```

---

## Мониторинг и управление

### Проверка состояния системы

```bash
# Запустить health check
sudo chmod +x k8s/scripts/health-check.sh
./k8s/scripts/health-check.sh
```

### Резервное копирование

```bash
# Создать backup
sudo chmod +x k8s/scripts/backup.sh
sudo ./k8s/scripts/backup.sh
```

### Zero-downtime обновления

```bash
# Запустить обновление с перезагрузкой
sudo chmod +x k8s/auto-k8s-smart-reboot.sh
sudo ./k8s/auto-k8s-smart-reboot.sh
```

---

## VPN конфигурация

### XRay Client Config (для подключения)

```json
{
  "v": "2",
  "ps": "K8s-VPN",
  "add": "IP вашего сервера",
  "port": "30443",
  "id": "Ваш сгенерированный ID",
  "aid": "0",
  "net": "tcp",
  "type": "none",
  "host": "www.google.com",
  "path": "",
  "tls": "reality",
  "sni": "www.google.com",
  "fp": "chrome",
  "alpn": "h2,http/1.1",
  "flow": "xtls-rprx-vision"
}
```

---

## Доступ к сервисам

После установки доступны:

- **Nginx HTTP**: `http://IP вашего сервера:30080`
- **XRay VPN**: `IP вашего сервера:30443`
- **Grafana**: `http://IP вашего сервера:31858`

**Grafana credentials:**
- Username: `admin`
- Password: `prom-operator`

---

## Безопасность

### Рекомендуемые настройки

1. **SSL сертификаты для nginx**
2. **Firewall правила**
3. **RBAC конфигурации**
4. **Network policies**

### Обновление ключей

```bash
# Генерировать новые ключи для XRay
openssl genpkey -algorithm x25519 -out private.key
openssl pkey -in private.key -pubout -out public.key
```

---

## Устранение неполадок

### Частые проблемы

```bash
# Проверить статус подов
kubectl get pods -A

# Посмотреть логи
kubectl logs -n vpn deployment/xray
kubectl logs -n vpn deployment/nginx

# Проверить события
kubectl get events --sort-by='.lastTimestamp'

# Диагностика кластера
kubectl cluster-info
kubectl get nodes -o wide
```

### Полезные команды

```bash
# Быстрая диагностика в виде алиаса k8s
alias k8s='kubectl get nodes; kubectl get pods -A; kubectl get svc -A'

# Проверка ресурсов
kubectl top nodes
kubectl top pods -A

# Перезапуск сервисов
kubectl rollout restart deployment/xray -n vpn
kubectl rollout restart deployment/nginx -n vpn
```

---

## Что реализовано

### Готово

- [x] **K8s Single Node Cluster** с kubeadm
- [x] **XRay VPN** с протоколом vless и Reality
- [x] **Nginx reverse proxy**
- [x] **Prometheus + Grafana** мониторинг
- [x] **Zero-downtime auto-reboot** система
- [x] **Автоматический uncordon** после перезагрузки
- [x] **Скрипты автоматизации** (install, deploy, backup, health-check)
- [x] **Health checks** и liveness/readiness probes

---