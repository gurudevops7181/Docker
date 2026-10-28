# Docker EFK and voting app examples

This repository contains Docker Compose and Docker Swarm examples for an Elasticsearch, Fluentd, and Kibana (EFK) logging stack, plus a multi-service voting app. These are lab examples, not production deployment templates.

## Files

| File | Purpose |
| --- | --- |
| `docker-compose` | Local Apache/Nginx and EFK stack. |
| `docker-stack` | Swarm Apache/Nginx and EFK stack. |
| `votingapp` | Swarm voting app without the external `efk` network. |
| `docker-stack-vote` | Swarm voting app attached to the external `efk` network. |
| `fluentd/fluentd.conf` | Fluentd forward input and Elasticsearch/stdout outputs. |
| `Dockerfile`, `fluentd/Dockerfile` | Identical Fluentd image definitions with the Elasticsearch output plugin. |
| `Dockerfile-Nginx-Logs-Redirect` | Nginx image that sends access and error logs to stdout and stderr. |

## Build the logging images

The Compose and Swarm manifests use these custom image tags. Build them before running Compose:

```sh
docker build -f fluentd/Dockerfile -t sreeharshav/efk_fluentd:v2 .
docker build -f Dockerfile-Nginx-Logs-Redirect -t sreeharshav/efknginx:v1 .
```

The Nginx build uses `sreeharshav/rollingupdate:v3` as its base image, which must be available to Docker. Swarm nodes must be able to pull the custom tags from a registry; push them if they are not already published:

```sh
docker push sreeharshav/efk_fluentd:v2
docker push sreeharshav/efknginx:v1
```

The voting stacks also reference `sreeharshav/example-voting-app_*` images. Those tags must be available to every Swarm node.

## Local Compose logging example

Start and stop the local stack with:

```sh
docker compose -f docker-compose up -d
docker compose -f docker-compose down
```

The manifest mounts the tracked `fluentd/fluentd.conf` file directly. Fluentd uses the Elasticsearch output plugin from the included Dockerfile. Elasticsearch and Kibana are pinned to matching version `9.5.5`; security is disabled for this local lab example. Their host ports bind to loopback:

| Service | Address | Purpose |
| --- | --- | --- |
| Apache | `http://localhost:80` | HTTP example |
| Nginx | `http://localhost:8000` | HTTP example |
| Elasticsearch | `http://localhost:9200` | Elasticsearch API |
| Kibana | `http://localhost:5601` | Kibana UI |
| Fluentd | `localhost:24224` TCP/UDP | Forward input |

Container log drivers send events to the Docker host's `localhost:24224`. Async connection is enabled so the web containers can start while Fluentd is coming up. Fluentd starts after Elasticsearch and restarts if the collector exits during Elasticsearch startup. Elasticsearch data is stored in the Compose volume `data01`.

## Docker Swarm EFK stack

Initialize Swarm if needed, create the external network and config once, then deploy:

```sh
docker swarm init
docker network create --driver overlay efk
docker config create conf fluentd/fluentd.conf
docker stack deploy -c docker-stack efk
```

The Fluentd config is mounted as `/fluentd/etc/fluent.conf`. The stack publishes Fluentd's port `24224`; the Docker logging driver on each node connects to that node's published port at `localhost:24224`. Elasticsearch and Kibana use version `9.5.5`; their security is disabled in these examples. Elasticsearch data is stored in the node-local Swarm volume `efk_esdata` on the manager node. The stack publishes Elasticsearch on `9200`, Kibana on `5601`, Apache on `80`, and Nginx on `8000`.

These Swarm ports are published across the cluster. Keep this unsecured example on a trusted lab network; do not expose it to the internet. Remove the stack with `docker stack rm efk`. The external network and config remain after stack removal.

## Voting app stacks

Both voting manifests define Redis, PostgreSQL, vote, result, and worker services. They publish the vote UI on port `5000`, the result UI on `5001`, and persist PostgreSQL data in `db-data`. The database image is `postgres:15-alpine`.

Deploy one of the files to an initialized Swarm:

```sh
docker stack deploy -c votingapp vote
# Or, after creating the external efk network:
docker stack deploy -c docker-stack-vote vote
```

`votingapp` uses only its `frontend` and `backend` networks. `docker-stack-vote` also joins the external `efk` network. Both configure the Fluentd logging driver at `localhost:24224`; a Fluentd endpoint must be published on each node for log forwarding. Remove the voting stack with `docker stack rm vote`.

The sample app images expect the demo PostgreSQL credentials `postgres` / `postgres`, so the manifests retain those values. These credentials are not suitable for a shared or production deployment; changing them also requires updating or rebuilding the app images to use the same credentials.

## Upgrade and compatibility notes

- The EFK manifests set `xpack.security.enabled=false` to keep the Fluentd and Kibana examples simple. Enable and configure authentication/TLS before using this beyond a trusted lab.
- The Elasticsearch image was updated from 7.2.0 to 9.5.5. Do not attach an old data volume directly to the new image. Follow Elastic's staged upgrade path through 7.17 and 8.19, and reindex or archive indices created in 7.x or earlier before moving to 9.x. See [Elastic's upgrade guide](https://www.elastic.co/docs/deploy-manage/upgrade/deployment-or-cluster/upgrade-717).
- The voting database was updated from PostgreSQL 9.4 to 15. Existing data in a volume initialized by PostgreSQL 9.4 cannot be reused directly by PostgreSQL 15; back it up and migrate it before deploying the updated stack.
- `docker-stack` uses external config `conf` and external overlay network `efk`. Create them before deploying; remove them only when no stacks depend on them.
- The image tags for the voting app and Nginx base image are external to this repository. Confirm they are accessible before deployment.
