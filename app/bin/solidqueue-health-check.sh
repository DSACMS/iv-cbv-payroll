#!/bin/bash
PIDFILE="tmp/solid_queue.pid"

if [[ ! -f "$PIDFILE" ]]; then
  echo "PID file missing"
  exit 1
fi

PID=$(cat "$PIDFILE")

if ps -p "$PID" > /dev/null; then
  echo "Solid Queue running"
  exit 0
else
  echo "Solid Queue not running"
  exit 1
fi
