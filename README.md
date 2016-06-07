hubot-ecs
=========

A hubot script for manage AWS ECS cluster via ecs-cli.

Installation
------------

In hubot project repo, run:

    npm install hubot-ecs --save

Then add **hubot-ecs** to your `external-scripts.json`:

```json
[
  "hubot-ecs"
]
```

Configuration
-------------

hubot-ecs can use [`hubot-auth`](https://github.com/hubot-scripts/hubot-auth) for restrict usage to certain roles.

Usage
-----

* hubot ecs list-cluster - Lists all of the ECS clusters.
* hubot ecs <cluster name> list-project - Lists all of the ECS projects in your cluster.
* hubot ecs <cluster name> ps - Lists all of the running containers in default ECS cluster.
* hubot ecs <cluster name> <project name> compose service ps - Lists all the containers in your cluster that belong to the service created with the compose project.
* hubot ecs <cluster name> <project name> compose service up - Creates an ECS service from your compose file (if it does not already exist) and runs one instance of that task on your cluster (a combination of create and start). This command updates the desired count of the service to 1.
* hubot ecs <cluster name> <project name> list-image - Lists all the images in your cluster that belong to the service created with the compose project.
* hubot ecs <cluster name> <project name> update-image <new image> - Updates your compose file with the new image.

Example
-------

    hubot> @hubot ecs list-cluster

    hubot> Clusters:
    hubot>   default

    hubot> @hubot ecs default list-project
    hubot>   example

    hubot> @hubot @user has default_admin role
    hubot>   OK, user has the 'default_admin' role.

Configuration
-------------

The ECS cluster default path is `hubot_dir/node_modules/hubot-ecs/src/ecs/`, you can override this path by set environment variable `HUBOT_ECS_CLUSTER_PATH`, and use cluster name as the directory name, then put your [Docker Compose](https://docs.docker.com/compose/) file into `HUBOT_ECS_CLUSTER_PATH/<cluster-name>`, Docker compose name as the ECS project name, the default authorized roles are `admin` and `ecs_admin`, and you can use environment variable `HUBOT_ECS_AUTHORIZED_ROLES` to override it.

Running hubot-ecs on Docker
---------------------------

    export HUBOT_AUTH_ADMIN=slack_user_id_1,slack_user_id_2
    export HUBOT_SLACK_TOKEN=slack_token
    export HUBOT_ECS_AUTHORIZED_ROLES=admin,ecs_admin
    export HUBOT_ECS_CLUSTER_PATH=/root/mybot/ecs

    docker rm -f redis_hubot_ecs &>/dev/null
    docker run \
        -d \
        --name redis_hubot_ecs \
        --restart=unless-stopped \
        -v "$(pwd)/data":/data:rw \
        redis:3.2.0-alpine \
        redis-server --appendonly yes

    docker rm -f hubot_ecs &>/dev/null
    docker run \
        -d \
        --name=hubot_ecs \
        --restart=unless-stopped \
        -e "HUBOT_AUTH_ADMIN=${HUBOT_AUTH_ADMIN}" \
        -e "REDIS_PORT=tcp://redis:6379" \
        -e "HUBOT_SLACK_TOKEN=${HUBOT_SLACK_TOKEN}" \
        -e "HUBOT_ECS_AUTHORIZED_ROLES=${HUBOT_ECS_AUTHORIZED_ROLES}" \
        -e "HUBOT_ECS_CLUSTER_PATH=${HUBOT_ECS_CLUSTER_PATH}" \
        -v "${HOME}/.ecs/cluster":/root/mybot/ecs:rw \
        -v "${HOME}/.ecs/config":/root/.ecs/config:ro \
        --link redis_hubot_ecs:redis \
        mlf4aiur/hubot-ecs

License
-------

This project is [BSD-3-Clause Licensed](https://github.com/mlf4aiur/hubot-ecs/master/LICENSE).
