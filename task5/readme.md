# Сетевые политики

## Что будет сделано скриптами ниже

- Неймспейс `netpol`
- 4 сервиса (Deployment + Service):
  - `front-end-app` (`role=front-end`)
  - `back-end-api-app` (`role=back-end-api`)
  - `admin-front-end-app` (`role=admin-front-end`)
  - `admin-back-end-api-app` (`role=admin-back-end-api`)
- Сетевые политики (основные):
  - `default-deny-all` - запрет всего трафика (Ingress + Egress)
  - `allow-dns-egress` - разрешение DNS‑трафика к `kube-dns`
  - Пары для пользовательского и админского трафика (Ingress/Egress отдельно):
    - `allow-egress-front-to-back`, `allow-ingress-back-from-front`
    - `allow-egress-back-to-front`, `allow-ingress-front-from-back`
    - `allow-egress-admin-front-to-admin-back`, `allow-ingress-admin-back-from-admin-front`
    - `allow-egress-admin-back-to-admin-front`, `allow-ingress-admin-front-from-admin-back`
- Автоматическая проверка политик скриптом [03-validate-netpolicy.sh](03-validate-netpolicy.sh)

## Содержимое директории с заданием

- [01-deploy-services.sh](01-deploy-services.sh) - создаёт namespace и разворачивает 4 Nginx сервиса
- [02-apply-netpolicy.sh](02-apply-netpolicy.sh) - применяет сетевые политики
- [03-validate-netpolicy.sh](03-validate-netpolicy.sh) - автоматические проверки корректности разрешений/запретов
- [04-cleanup.sh](04-cleanup.sh) - удаляет namespace целиком
- Директория [yaml/](yaml/) - манифесты Kubernetes:
  - [01-namespace.yaml](yaml/01-namespace.yaml) - собственно сам неймспейс (`netpol`)
  - [10-nginx-services.yaml](yaml/10-nginx-services.yaml) - 4 сервиса с нужными метками (`role`)
  - [20-default-deny.yaml](yaml/20-default-deny.yaml) - базовый запрет всего трафика
  - [21-non-admin-api-allow.yaml](yaml/21-non-admin-api-allow.yaml) - разрешения для пары `front-end` <-> `back-end-api`
  - [22-admin-api-allow.yaml](yaml/22-admin-api-allow.yaml) - разрешения для пары `admin-front-end` <-> `admin-back-end-api`
  - [23-allow-dns.yaml](yaml/23-allow-dns.yaml) - разрешение egress к DNS (`kube-dns`)
- Директория [lib/](lib/) - вспомогательные функции:
  - [steps.sh](lib/steps.sh) - для красивого вывода в терминал
  - [test-functions.sh](lib/test-functions.sh) - функции для тестирования

## Запуск

### Требования

- Рабочий кластер Kubernetes (Minikube)
- kubectl настроен на контекст кластера
- Консоль с Bash
- Включённый CNI с поддержкой NetworkPolicy:
  - Вариант 1 (так проще): старт кластера с флагом `--cni=calico`
  - Вариант 2 (для уже запущенного кластера): установить Calico манифестом:
    - `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml`

Проверки в `03-validate-netpolicy.sh` это тоже проверят, выведут сообщение об ошибке, если не найдётся.


### Рекомендуемый порядок запуска

- Поднять Minikube с CNI, поддерживающим NetworkPolicy:

  ```bash
  minikube delete
  minikube start --driver=docker --cni=calico
  ```

- Развернуть сервисы и политики, запустите проверки:

  ```bash
  cd task5
  ./01-deploy-services.sh
  ./02-apply-netpolicy.sh
  ./03-validate-netpolicy.sh
  ```

- Очистить minikube

   ```bash
   ./04-cleanup.sh
   ```

## Результаты

Ожидаемое поведение:
- Разрешено: `front-end` <-> `back-end-api`, `admin-front-end` <-> `admin-back-end-api`.
- Запрещено: любые перекрёстные обращения между пользовательскими и админскими ролями.
