# Running Local Container with Proper Volume Mounting

When running the application container locally, it's important to properly mount the `/rails/tmp` and `/rails/log` directories as volumes. This ensures that the container has writable locations for temporary files, PID files, logs, and other runtime data.

## Using the run-local-container.sh Script

We've created a script to simplify running containers with proper volume mounting:

```bash
# Build the container first if needed
APP_NAME=app make release-build

# Run the container with proper volume mounting
./bin/run-local-container.sh iv-cbv-payroll-app:latest

# You can also pass additional docker run options
./bin/run-local-container.sh iv-cbv-payroll-app:latest -it bash
```

## Manual Docker Run Command

If you prefer to run the container manually, use this command structure:

```bash
# Create directories if they don't exist
mkdir -p "$(pwd)/tmp"
mkdir -p "$(pwd)/log"

# Run the container with proper volume mounting
docker run \
  --mount type=bind,source="$(pwd)/tmp",target=/rails/tmp \
  --mount type=bind,source="$(pwd)/log",target=/rails/log \
  --publish 3000:3000 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e RAILS_SERVE_STATIC_FILES=true \
  iv-cbv-payroll-app:latest
```

## Why This Is Necessary

The container needs writable directories for its operation. Without proper volume mounting:

1. The container will report "No existing PID file found at /rails/tmp/pids/server.pid"
2. The application will fail with "Rails Error: Unable to access log file" and "Read-only file system" errors
3. The application may fail to access the master.key file due to permission issues
4. Temporary files and logs won't persist between container restarts

By mounting both the `/rails/tmp` and `/rails/log` directories as volumes and removing the read-only constraint, you ensure the container has the necessary writable locations for its runtime data.