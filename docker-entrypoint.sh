#!/bin/bash
set -e

# start gem installation before db started
. ./.env
export $(cut -d= -f1 .env)

# check if db is availible to start migrations
port="$1"
while ! nc -z db $port; do sleep 3; done

mix run script/setup.exs
sh script/run_local.sh
