#!/bin/bash

# Загрузка переменных окружения из .env файла
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found. Exiting."
    exit 1
fi

# Создаем директорию для хранения секретов
mkdir -p .secrets

# Сохраняем пароли в файлы
echo "$XTRABACKUP_PASSWORD" > .secrets/xtrabackup_password
echo "$MYSQL_PASSWORD" > .secrets/mysql_password
echo "$MYSQL_ROOT_PASSWORD" > .secrets/mysql_root_password

# Развертывание Docker стека
docker stack deploy -c docker-compose.yml galera

# Функция для проверки здоровья сервиса
check_service_health() {
    local service_name=$1
    while true; do
        container_id=$(docker ps -q --filter "name=${service_name}")
        if [ -z "$container_id" ]; then
            echo "No containers found for service $service_name. Waiting..."
            sleep 5
            continue
        fi

        health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}unhealthy{{end}}' $container_id)
        if [ "$health_status" == "healthy" ]; then
            echo "$service_name is healthy!"
            break
        else
            echo "Still waiting for $service_name to be healthy (current status: $health_status)..."
            sleep 5
        fi
    done
}

# Ожидаем, пока сервис galera_seed не станет здоровым
echo "Waiting for galera_seed to be healthy..."
check_service_health galera_seed

# Масштабирование galera_node до 2 экземпляров
docker service scale galera_node=2

# Ожидаем, пока оба экземпляра galera_node не станут здоровыми
echo "Waiting for both galera_node instances to be healthy..."
check_service_health galera_node

# Масштабирование galera_seed до 0 экземпляров
docker service scale galera_seed=0

# Масштабирование galera_node до 3 экземпляров
docker service scale galera_node=3

echo "Galera cluster deployment and scaling complete!"
