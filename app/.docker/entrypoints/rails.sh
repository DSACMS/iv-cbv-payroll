#!/bin/bash
set -e

echo "Starting rails.sh script..."

echo "Docker System Information:"
echo "Current user: $(whoami)"
echo "Current user's groups: $(groups)"
echo "Directory permissions:"
ls -la / | grep -E "^d"
echo "Rails directory permissions:"
ls -la /rails | grep -E "^d"

# list all files in /rails/tmp
echo "Files in /rails/tmp:"
ls -la /rails/tmp

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
