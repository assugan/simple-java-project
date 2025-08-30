# Diploma DevOps Project

## 📌 Описание

Полноценный DevOps-проект для демонстрации навыков CI/CD, IaC и мониторинга.  
Реализует полный цикл доставки и эксплуатации Java-приложения:

- **CI/CD**: Jenkins (Multibranch Pipeline).
- **IaC**: Terraform + Ansible.
- **Контейнеризация**: Docker, Docker Compose, DockerHub.
- **Мониторинг**: Prometheus + Grafana + Node Exporter + cAdvisor.
- **Облачная инфраструктура**: AWS EC2.

---

## ⚙️ Архитектура

### Основные компоненты:
- **Java-приложение (Maven App)**  
  Простое приложение на Java (Maven), контейнеризованное в Docker-образ.

- **Terraform**  
  Создаёт инфраструктуру в AWS:
  - VPC, Subnet, Internet Gateway.
  - EC2-инстанс (Ubuntu 22.04).
  - Security Group с доступом по портам:
    - `22` (SSH),
    - `8080` (приложение),
    - `9090` (Prometheus),
    - `3000` (Grafana).

- **Ansible**  
  После создания инстанса:
  - Устанавливает Docker и Docker Compose plugin.
  - Разворачивает приложение через `docker-compose.yml`.
  - Разворачивает мониторинг (Prometheus, Grafana, Node Exporter, cAdvisor).

- **Jenkins**  
  Multibranch Pipeline:
  - **Любая ветка / Pull Request**: линтер, сборка, тесты.
  - **main (после merge)**: дополнительно билд Docker-образа, push в DockerHub и деплой на EC2.

- **Prometheus & Grafana**  
  Автоматически разворачиваются через Ansible, подключены через provisioning:
  - Datasource Prometheus.
  - Автоимпорт дашборда с метриками (CPU, RAM, FS, контейнеры).

---

## 🚀 CI/CD Pipeline (Jenkins)

### Логика пайплайна

- **Pull Request (draft-branch → main)**:
  - Линтер (checkstyle).
  - Сборка (Maven package).
  - Тесты (Maven test).
  - ✅ Результат: статусы в GitHub PR.

- **Merge в main**:
  - Всё выше.
  - Docker Buildx (multi-arch) и push в DockerHub:
    - Теги: `<branch>-<short_sha>`, `<build_number>`, `latest`.
  - Деплой на EC2 через Ansible:
    - Замена `docker-compose.yml`.
    - Перезапуск контейнера приложения.
    - Запуск мониторинга.

### Jenkinsfile (ключевые моменты)

- Линтер, Build, Test для всех веток.
- Docker Push + Deploy только для `main` и только если это **не PR**.
- Jenkins запускается через GitHub Webhook.
---