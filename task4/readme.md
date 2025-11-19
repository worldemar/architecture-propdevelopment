# RBAC для Kubernetes

## Файлы

- Скрипты:
  - [01-create-users.sh](01-create-users.sh) — создаёт namespaces и ServiceAccount’ы
  - [02-create-roles.sh](02-create-roles.sh) — создаёт ClusterRole/Role
  - [03-bind-users-roles.sh](03-bind-users-roles.sh) — создаёт ClusterRoleBinding/RoleBinding
  - [04-validate-rbac.sh](04-validate-rbac.sh) — прогоняет проверки RBAC (структурные и функциональные)
- Общие функции:
  - [lib/steps.sh](lib/steps.sh) — вывод шагов в едином формате
  - [lib/test-functions.sh](lib/test-functions.sh) — утилиты для тестов (can‑i, verbs, создание Job/CronJob и т. п.)
- YAML‑манифесты:
  - [yaml/01-namespaces.yaml](yaml/01-namespaces.yaml) — список Namespace (`rbac`, `sales`, `utilities`, `finance`, `data`)
  - [yaml/01-serviceaccounts.yaml](yaml/01-serviceaccounts.yaml) — `ServiceAccount` для привилегий и доменных команд
  - [yaml/02-clusterroles.yaml](yaml/02-clusterroles.yaml) — ClusterRole-и: `privileged-admin`, `platform-operator`, `readonly-custom`
  - [yaml/02-roles.yaml](yaml/02-roles.yaml) — допустимые действия для `sales`, `utilities`, `finance`, `data`
  - [yaml/03-clusterrolebindings.yaml](yaml/03-clusterrolebindings.yaml) — `ClusterRoleBinding` для привязки SA к кластерным ролям
  - [yaml/03-rolebindings.yaml](yaml/03-rolebindings.yaml) — `RoleBinding` для привязки SA к ролям в namespace
- Таблица ролей:
  - [roles-table.md](roles-table.md)

## Предварительные требования

- Рабочий кластер Kubernetes (Minikube).
- kubectl настроен на нужный контекст.
- Bash (скрипты рассчитаны на запуск через bash).

## Как запустить кластер (Minikube)

- Если Docker Desktop:
  - `minikube start --driver=docker`
- Если Hyper‑V:
  - `minikube start --driver=hyperv --hyperv-virtual-switch "Default Switch"`
- Проверка подключения:
  - `kubectl config current-context`
  - `kubectl get nodes`
  - `minikube status`

## Установка RBAC (по шагам)

- `bash 01-create-users.sh`
- `bash 02-create-roles.sh`
- `bash 03-bind-users-roles.sh`

## Валидация RBAC

- Запустите:
  - `bash 04-validate-rbac.sh`
- Скрипт проверяет:
  - Структуру RoleBinding’ов: ns‑developer‑binding привязан к ожидаемым ServiceAccount’ам в каждом namespace.
  - Права ролей через kubectl auth can-i на полный набор глаголов (get, list, watch, create, update, patch, delete) для ключевых ресурсов (configmaps, deployments, jobs, cronjobs и др.).
  - Реальные операции (create/patch/update/delete) для минимального подтверждения прав (deployment/configmap/job/cronjob) с последующим cleanup.
- Если права не заданы или заданы неверно — увидите [FAIL] с описанием причины.

## Диагностика проблем

- Нет подключения к API:
  - Проверьте: `kubectl cluster-info`
  - Убедитесь, что Minikube запущен и контекст выбран.
- Ошибка в правах:
  - Перезапустите создание ролей: `bash 02-create-roles.sh`
  - Проверьте биндинги: `bash 03-bind-users-roles.sh`
- Метрики (необязательно, но полезно):
  - `minikube addons enable metrics-server`

## Очистка (tear‑down)

- Удалить тестовые ресурсы и все созданные RBAC‑объекты:
  - `bash 05-cleanup.sh`
- Что делает скрипт:
  - Удаляет меткой `rbac-lab=task4` тестовые `Deployment/Job/CronJob/ConfigMap` во всех неймспейсах.
  - Удаляет `RoleBinding/ClusterRoleBinding`, затем `Role/ClusterRole`, затем `ServiceAccount`, затем `Namespace`.

## Зачем нужен namespace `rbac`

- Отдельный namespace `rbac` используется для хостинга привилегированных сервисных аккаунтов (`priv-admin`, `ops`, `viewer`). Это упрощает разграничение и аудит прав.