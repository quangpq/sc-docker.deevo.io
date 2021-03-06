#!/bin/bash

set -e

mkdir -p data
mkdir -p data-config
mkdir -p data/logs
sudo rm -rf data/channel-artifacts/*
sudo rm -rf data/logs/*
sudo rm -rf data-config/*
mkdir -p data

# Remove all containers
for pid in $(docker ps -a -q); do
    if [ $pid != $$ ]; then
        echo "Container is already running $pid"
        docker rm -f $pid
    fi
done

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/base-solo-network-only.yaml up
