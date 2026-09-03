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

# Expand the JSON credentials secret into the environment variables used by the
# FDSH client. Shellwords.escape preserves PEM newlines and keeps secret values
# out of the startup log.
if [ -n "${HUB_CREDENTIALS_JSON:-}" ]; then
  HUB_CREDENTIAL_EXPORTS=$(
    ruby -rjson -rshellwords -e '
      credentials = JSON.parse(ENV.fetch("HUB_CREDENTIALS_JSON"))
      {
        "cert" => "HUB_CLIENT_CERT",
        "certKey" => "HUB_CLIENT_KEY",
        "clientKey" => "HUB_CLIENT_ID",
        "clientSecret" => "HUB_CLIENT_SECRET"
      }.each do |source, target|
        puts "export #{target}=#{Shellwords.escape(credentials.fetch(source))}"
      end
    '
  )
  eval "$HUB_CREDENTIAL_EXPORTS"
  unset HUB_CREDENTIAL_EXPORTS HUB_CREDENTIALS_JSON
fi

# Log the command that will be executed
echo "Preparing to execute command: $@"

# Execute the passed command (should be the rails server command)
echo "Executing command..."
exec "$@"
