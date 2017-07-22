#!/usr/bin/env bash

_start_sokratbot() {
  echo "Starting application"
  elixir --detached -e "File.write! 'tmp/pids/bot.pid', :os.getpid" -S mix run --no-halt
}

cwd=$(pwd)
cd $APP_DIR
pid_file=$APP_DIR/tmp/pids/bot.pid

if [ -f $pid_file ]; then
  echo "PID file is found"

  if kill $( cat $pid_file ) > /dev/null 2>&1; then
    echo "Stopping application"
  else
    echo "Application was not run"
  fi
else
  echo "PID file is not found"
fi

_start_sokratbot
cd $cwd
