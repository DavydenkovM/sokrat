#!/usr/bin/env bash

_start_sokratbot() {
  echo "Starting application"
  mix run --no-halt
}

. .env
export $(cut -d= -f1 .env)
_start_sokratbot
