# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.1.0

FROM node:20.12.0-bullseye-slim AS node-stage
WORKDIR /rails
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git

RUN apt-get install --reinstall ca-certificates -y && \
    update-ca-certificates

# print the node version
RUN node --version
COPY package.json ./
RUN yarn install

##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000

##########################################################################################
# BUILD: Throw-away build stage
##########################################################################################
FROM base as build
ARG DOCKERIZE_VERSION=v0.7.0
#copy the node binary from the node-stage to the base image
COPY --from=node-stage /usr/local/bin/node /usr/local/bin/node

# Install dockerize
RUN apt-get update \
    && apt-get install -y wget \
    && wget -O - https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz | tar xzf - -C /usr/local/bin \
    && apt-get autoremove -yqq --purge wget && rm -rf /var/lib/apt/lists/*

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config redis jq rbenv cu npm


# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

##########################################################################################
# DEV: Used for development and test
##########################################################################################
FROM build as dev

WORKDIR /rails

ENV RAILS_ENV="development"

# Install packages needed for development
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y postgresql-client graphviz && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install bundler

# Install application gems for development
COPY Gemfile Gemfile.lock ./

RUN gem update --system
RUN bundle lock --add-platform ruby && \
    bundle lock --add-platform x86_64-linux

RUN bundle config set --local without production && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# copy node from node-stage to dev
COPY --from=node-stage /usr/local/bin/node /usr/local/bin/node
# Copy application code
COPY . .
# Copy node_modules from node-stage
COPY --from=node-stage /rails/node_modules ./
ENTRYPOINT [".docker/.entrypoints/docker-rails.sh"]

##########################################################################################
# RELEASE-BUILD: Throw-away build stage for RELEASE
##########################################################################################
FROM build as release-build

# Install application gems for production
COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without development test && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


##########################################################################################
# RELEASE: Used for production
##########################################################################################
FROM base as release

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends unzip python3-venv python-is-python3  curl libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm -rf ./awscli-bundle awscli-bundle.zip

# Install custom db migrate script
COPY bin/db-migrate /usr/bin/

# Copy built artifacts: gems, application
COPY --from=release-build /usr/local/bundle /usr/local/bundle
COPY --from=release-build /rails /rails

RUN rm /rails/tmp/pids/server.pid

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

ENTRYPOINT [".docker/.entrypoints/docker-rails.sh"]