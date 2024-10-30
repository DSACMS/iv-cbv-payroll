# Running Built Images Locally

When debugging problems that are hard to reproduce locally, you may find it useful to run a production image locally.

Follow these steps to run an image that was built to deploy to demo/production:

```
# 1. Authenticate to AWS Elastic Container Repository:
AWS_PROFILE=prod aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 730335532059.dkr.ecr.us-east-1.amazonaws.com

# 2. Get the latest Production image name
image_tag=$(curl https://snap-income-pilot.com/health | jq -r .version)
image_name="730335532059.dkr.ecr.us-east-1.amazonaws.com/iv-cbv-payroll-app:$image_tag"

# 3. Run the docker image
# (in the "app" subdirectory)
docker run --read-only --mount type=bind,source=$(pwd)/tmp,target=/rails/tmp --publish 3001:3000 --env-file .env --env-file .env.development.local -e GNUPGHOME=/rails/tmp -e SECRET_KEY_BASE=$(openssl rand -hex 64) -e DOMAIN_NAME="localhost:3000" -e RAILS_SERVE_STATIC_FILES=true -ti "$image_name" bash

# 4. In the docker image, start the server:
bin/rails server

# 5. Since we require TLS in production, you will need to run a local proxy (outside docker):
npx local-ssl-proxy --source 3000 --target 3001

# 6. Access it in your browser at https://localhost:3000. (Disregard the security warning.)
#
# Note that most functionality will not work - as this will not connect to the
# database properly. (You will need to pass more environment variables for that
to work.)
```

:warning: **Warning:** The docker image repository is hosted in our production account. You should not push to the production image repository under any normal circumstance - let's make sure all our images are built via Github Actions!
