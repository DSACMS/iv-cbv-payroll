#!/bin/bash
set -e
# Remove stale PID file if it exists
PIDFILE="/rails/tmp/pids/server.pid"
if [ -f $PIDFILE ]; then
  echo "Removing stale PID file: $PIDFILE"
  rm -f $PIDFILE
  echo "Stale PID file removed."
else
  echo "No existing PID file found at $PIDFILE"
fi

# Log the command that will be executed
echo "Preparing to execute command: $@"

# Execute the passed command (should be the rails server command)
echo "Executing command..."
exec "$@"
