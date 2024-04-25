#!/bin/sh

set -e

if [ -f /rails/tmp/pids/server.pid ]; then
  rm /rails/tmp/pids/server.pid
fi

/rails/bin/rails db:migrate

bundle exec rails s -b 0.0.0.0

