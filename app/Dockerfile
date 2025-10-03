# syntax = docker/dockerfile:1

# Steps for upgrading Ruby version / base image:
# 1. Update the version number in three places:
#      1. Here
#      2. .ruby-version
#      3. Gemfile
# 2. Run `bin/update` and commit changes.
# 3. Update Dockerfile to address any upgrades from the base ruby image.
#      * Update versions of pinned debian packages
#      * Remove manual security upgrades (if any)
# 4. Ensure that docker build pasess:
#      > make release-build OPTS="--tag iv-cbv-payroll:latest"
# 5. Ensure that `wkhtmltopdf` runs:
#      > docker run iv-cbv-payroll:latest bundle exec wkhtmltopdf --version
ARG RUBY_VERSION=3.4.5


##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/ruby:$RUBY_VERSION AS base

# Upgrade packages in base image to address security issues.
# We should be able to remove these after upgrading the base image to a version
# that has the upgraded versions by default.
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -y --no-install-recommends \
      libtasn1-6 \
      libgnutls30 \
      imagemagick \
      libc-dev-bin \
      liblzma5 \
      linux-libc-dev \
      libxml2 libxml2-dev \
      libxslt1-dev \
      icu-devtools libicu-dev \
    ; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLER_VERSION='2.4'

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000


##########################################################################################
# BUILD: Throw-away build stage
##########################################################################################
FROM base AS build

# Install packages needed to build gems
RUN set -eux; \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libexpat1 \
      libsqlite3-0 \
      libperl5.40 \
      perl \
      perl-base \
      perl-modules-5.40 \
    ; \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libpq-dev \
      npm \
      pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy application code
COPY . .

# chromium is not available for arm64, this could be problematic when developing locally on an arm64 machine
# and running tests that require puppeteer.
# Set default value for PUPPETEER_SKIP_CHROMIUM_DOWNLOAD
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Detect architecture and skip the installation of chromium if the architecture is arm64
# see https://github.com/puppeteer/puppeteer/issues/7740#issuecomment-1016083451
RUN if [ "$(uname -m)" = "arm64" ]; then \
      export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=false; \
    fi

RUN PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=$PUPPETEER_SKIP_CHROMIUM_DOWNLOAD npm install

##########################################################################################
# DEV: Used for development and test
##########################################################################################
FROM build AS dev

ENV RAILS_ENV="development"

# Set the tmp dir to the writeable tmp volume
ENV TMPDIR="/rails/tmp"

# Install packages needed for development
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      postgresql-client-17 \
      graphviz \
    ; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN gem install bundler --no-document -v ${BUNDLER_VERSION} && \
    bundle config set --local without production && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

CMD ["./bin/dev"]

##########################################################################################
# RELEASE-BUILD: Throw-away build stage for RELEASE
##########################################################################################
FROM build AS release-build

RUN bundle config set --local without development test && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

##########################################################################################
# RELEASE: Used for production
##########################################################################################
FROM base AS release

WORKDIR /rails

# Copy the entrypoint script
# See - https://www.docker.com/blog/docker-best-practices-choosing-between-run-cmd-and-entrypoint/
COPY .docker/entrypoints/rails.sh /usr/bin/
RUN chmod +x /usr/bin/rails.sh

# Set the tmp dir to the writeable tmp volume
ENV TMPDIR="/rails/tmp"
ENV GNUPGHOME="/rails/tmp"
ENV PIDFILE="/rails/tmp/pids/server.pid"

# Install packages needed for deployment
#
# To debug a missing package version (i.e. if one of these versions gets
# superceded in the upstream package repo), run:
#
#   docker run -ti registry.docker.com/library/ruby:3.3.5 bash
#   apt-get install [package]
#
# and notice the version that was installed.
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -y --no-install-recommends \
      libgpgme11t64 \
      libvips42 \
      openssl \
      postgresql-client-17 \
      python-is-python3 \
      python3-venv \
      python3-pip \
    ; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    python3 -m venv /opt/aws-cli-venv && \
    /opt/aws-cli-venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/aws-cli-venv/bin/pip install --no-cache-dir "setuptools>=78.1.1" && \
    /opt/aws-cli-venv/bin/pip install --no-cache-dir awscli && \
    ln -s /opt/aws-cli-venv/bin/aws /usr/local/bin/aws

# Remove unneeded stdlib gems if present. Uninstall executibles, all versions, ignore if not installed
RUN gem uninstall -x -aIx debug || true && \
    gem uninstall -x -aIx rss || true && \
    gem uninstall -x -aIx rexml || true && \
    gem uninstall -x -aIx net-imap || true

# Install custom db migrate script
COPY bin/db-migrate /usr/bin/

# Copy built artifacts: gems, application, binary dependencies
COPY --from=release-build /usr/local/bundle /usr/local/bundle
COPY --from=release-build /rails /rails

# Clean up any unused gems and ensure we have the correct versions
RUN bundle clean --force && \
    bundle install --no-cache

# Ensure all necessary directories exist
RUN mkdir -p /rails/tmp/pids /rails/log /rails/db

# Create volume for /rails/tmp
VOLUME /rails/tmp

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash --home /rails

# Set permissions and ownership for the runtime files
RUN chown -R rails:rails /rails/tmp /rails/log /rails/db /usr/local/bundle

# Switch to non-root user
USER rails:rails

# Invoke the entrypoint script, passing it the rails server command
ENTRYPOINT ["rails.sh"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
