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
        # Получаем список задач сервиса
        tasks=$(docker service ps --filter "desired-state=running" --format "{{.ID}} {{.Node}} {{.CurrentState}}" $service_name)

        if [ -z "$tasks" ]; then
            echo "No running tasks found for service $service_name. Waiting..."
            sleep 5
            continue
        fi

        all_healthy=true
        for task in "$tasks"; do
            task_id=$(echo $task | awk '{print $1}')
            task_state=$(echo $task | awk '{print $3}')

            if [[ "$task_state" != "Running" ]] && [[ "$task_state" != "Ready" ]] && [[ "$task_state" != "Starting" ]]; then
                all_healthy=false
                echo "Task $task_id is not in a healthy state (current state: $task_state). Waiting..."
                break
            fi
        done

        if [ "$all_healthy" = true ]; then
            echo "Service $service_name is healthy!"
            break
        else
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
