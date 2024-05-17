#!/bin/sh

echo "Starting Rails application in production mode..."
export RAILS_ENV=production

set -e

if [ -f /rails/tmp/pids/server.pid ]; then
  rm /rails/tmp/pids/server.pid
fi

bundle exec rails server -b 0.0.0.0 -p 3000
