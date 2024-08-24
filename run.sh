#!/bin/bash

# Создаем директорию для хранения секретов
mkdir -p .secrets

# Генерируем пароли и сохраняем их в файлы
openssl rand -base64 32 > .secrets/xtrabackup_password
openssl rand -base64 32 > .secrets/mysql_password
openssl rand -base64 32 > .secrets/mysql_root_password

# Развертывание Docker стека
docker stack deploy -c docker-compose.yml galera

# Ожидаем, пока сервис galera_seed не станет здоровым
echo "Waiting for galera_seed to be healthy..."
while [ "$(docker service ls --filter name=galera_seed -q)" ]; do
    if [ "$(docker inspect --format='{{.State.Health.Status}}' $(docker ps -q --filter name=galera_seed))" == "healthy" ]; then
        echo "galera_seed is healthy!"
        break
    else
        echo "Still waiting for galera_seed to be healthy..."
        sleep 5
    fi
done

# Масштабирование galera_node до 2 экземпляров
docker service scale galera_node=2

# Ожидаем, пока оба экземпляра galera_node не станут здоровыми
echo "Waiting for both galera_node instances to be healthy..."
while [ "$(docker inspect --format='{{.State.Health.Status}}' $(docker ps -q --filter name=galera_node))" != "healthy" ]; do
    echo "Still waiting for galera_node instances to be healthy..."
    sleep 5
done

# Масштабирование galera_seed до 0 экземпляров
docker service scale galera_seed=0

# Масштабирование galera_node до 3 экземпляров
docker service scale galera_node=3

echo "Galera cluster deployment and scaling complete!"
