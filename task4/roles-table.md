| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| privileged-admin | Кластерный доступ только для чтения ко всем стандартным ресурсам (pods, services, configmaps, deployments и др.) плюс доступ к secrets (get, list, watch) во всех namespace. Используется для привилегированных диагностик и инцидент‑респонса. | Специалисты по ИБ и ограниченная группа администраторов (SecOps/IR). |
| platform-operator | Кластерный доступ на управление рабочими нагрузками: get, list, watch, create, update, patch, delete для deployments, statefulsets, daemonsets, replicasets, services, ingresses, jobs, cronjobs, pods, configmaps. Без доступа к secrets. | Платформенная команда/DevOps (операторы кластера). |
| readonly-custom | Кластерный доступ только на чтение (get, list, watch) к типовым ресурсам приложений: pods, services, configmaps, deployments, ingresses, jobs, cronjobs, namespaces. Без доступа к secrets. | Аудиторы, менеджеры, служба поддержки (read‑only). |
| ns-developer | Доступ внутри своего namespace: полное управление приложенческими ресурсами (deployments, services, ingresses, configmaps, pods, jobs, cronjobs и др.) без доступа к secrets. | Продуктовые команды доменов: Sales, Utilities (ЖКУ), Finance, Data. Каждая команда работает в своём namespace. |


