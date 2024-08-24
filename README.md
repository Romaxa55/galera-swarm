# Galera Cluster Deployment

This project deploys a Galera Cluster using Docker Swarm. The deployment includes both a seed node and worker nodes, and supports automatic scaling of the cluster.

## Prerequisites

- Docker and Docker Swarm initialized on all nodes.
- The following secrets should be created before deployment:

```bash
mkdir -p .secrets
openssl rand -base64 32 > .secrets/xtrabackup_password
openssl rand -base64 32 > .secrets/mysql_password
openssl rand -base64 32 > .secrets/mysql_root_password
```

## Docker Compose File

The `docker-compose.yml` file is configured to deploy a Galera Cluster with the following services:

- **seed**: The initial seed node for the cluster.
- **node**: Additional nodes for the cluster, scaled according to the requirements.

### Docker Compose File Structure

```yaml
version: '3.9'

services:
  seed:
    image: colinmollenhour/mariadb-galera-swarm:10.11.6-2023-12-09
    environment:
      - XTRABACKUP_PASSWORD_FILE=/run/secrets/xtrabackup_password
      - MYSQL_USER=${MYSQL_USER:-db_user_default}
      - MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
      - MYSQL_DATABASE=${MYSQL_DATABASE:-database}
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
      - NODE_ADDRESS=${NODE_ADDRESS:-^10.0.*.*}
    networks:
      - galera_network
    command: seed
    volumes:
      - mysql-data:/var/lib/mysql
    secrets:
      - xtrabackup_password
      - mysql_password
      - mysql_root_password
  
  node:
    image: colinmollenhour/mariadb-galera-swarm:10.11.6-2023-12-09
    environment:
      - XTRABACKUP_PASSWORD_FILE=/run/secrets/xtrabackup_password
      - NODE_ADDRESS=${NODE_ADDRESS:-^10.0.*.*}
      - HEALTHY_WHILE_BOOTING=1
    networks:
      - galera_network
    command: node tasks.seed,tasks.node
    volumes:
      - mysql-data:/var/lib/mysql
    deploy:
      replicas: 0
      placement:
        max_replicas_per_node: 1
        constraints:
          - node.role == manager
    secrets:
      - xtrabackup_password

volumes:
  mysql-data:
    name: '{{.Service.Name}}-{{.Task.Slot}}-data'
    driver: local

networks:
  galera_network:
    driver: overlay

secrets:
  xtrabackup_password:
    file: .secrets/xtrabackup_password
  mysql_password:
    file: .secrets/mysql_password
  mysql_root_password:
    file: .secrets/mysql_root_password
```

## Deployment Instructions

1. **Create the necessary secrets**:

```bash
mkdir -p .secrets
openssl rand -base64 32 > .secrets/xtrabackup_password
openssl rand -base64 32 > .secrets/mysql_password
openssl rand -base64 32 > .secrets/mysql_root_password
```

2. **Deploy the stack**:

```bash
docker stack deploy -c docker-compose.yml galera
```

3. **Check the services**:

```bash
docker service ls
```

   Wait for the `galera_seed` service to become healthy.

4. **Scale the `galera_node` service**:

```bash
docker service scale galera_node=2
```

   Wait for both `galera_node` instances to become healthy.

5. **Scale down the `galera_seed` service**:

```bash
docker service scale galera_seed=0
```

6. **Scale up the `galera_node` service to 3 instances**:

```bash
docker service scale galera_node=3
```

## Environment Variables

- `MYSQL_USER`: The MySQL user to be created. Default is `db_user_default`.
- `MYSQL_DATABASE`: The database to be created. Default is `database`.
- `NODE_ADDRESS`: The address pattern for node IPs. Default is `^10.0.*.*`.

These can be overridden by specifying them in an `.env` file or passing them as environment variables during deployment.

## Troubleshooting

If you encounter any issues, make sure that:
- All nodes are part of the Docker Swarm.
- The necessary secrets have been created and are accessible.
- The Docker Swarm network is correctly configured to allow communication between nodes.

For more detailed logs, use:

```bash
docker service logs -f <service_name>
```
