#!/usr/bin/env bash

set -e

kind delete cluster
docker rm -f $(docker ps -a -q)
docker system prune -a -f --volumes
