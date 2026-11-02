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
# 5. Verify Chromium is available:
#      > docker run --entrypoint chromium iv-cbv-payroll:latest --version
ARG RUBY_VERSION=3.4.9


##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/node:24.22.1-bookworm-slim AS node-runtime

FROM registry.docker.com/library/ruby:$RUBY_VERSION AS base
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node

# Upgrade packages in base image to address security issues.
# We should be able to remove these after upgrading the base image to a version
# that has the upgraded versions by default.
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      # CVE-2026-28693 \
      imagemagick \
      # CVE-2026-33416 \
      libpng-dev \
      # CVE-2026-4775 \
      libtiff-dev \
      # CVE-2026-2673 \
      libssl-dev \
      # CVE-2026-3497 \
      openssh-client \
      # CVE-2026-4437 \
      libc-bin libc-dev-bin libc6 libc6-dev \
      # CVE-2025-68431 CVE-2026-32740 CVE-2026-32882 CVE-2026-47178 \
      libheif1 \
    && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Auto-fix: OS package vulnerabilities detected by Trivy and Grype (managed automatically)
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      bsdutils \
      curl \
      gir1.2-glib-2.0 \
      gir1.2-glib-2.0-dev \
      gir1.2-rsvg-2.0 \
      girepository-tools \
      gzip \
      krb5-multidev \
      libaprutil1t64 \
      libblkid-dev \
      libblkid1 \
      libbrotli-dev \
      libbrotli1 \
      libcap2 \
      libcurl3t64-gnutls \
      libcurl4-openssl-dev \
      libcurl4t64 \
      libde265-0 \
      libevent-2.1-7t64 \
      libevent-core-2.1-7t64 \
      libevent-dev \
      libevent-extra-2.1-7t64 \
      libevent-openssl-2.1-7t64 \
      libevent-pthreads-2.1-7t64 \
      libexif-dev \
      libexif12 \
      libexpat1 \
      libexpat1-dev \
      libgcrypt20 \
      libgio-2.0-dev \
      libgio-2.0-dev-bin \
      libgirepository-2.0-0 \
      libglib2.0-0t64 \
      libglib2.0-bin \
      libglib2.0-data \
      libglib2.0-dev \
      libglib2.0-dev-bin \
      libgraphite2-3 \
      libgraphite2-dev \
      libgssapi-krb5-2 \
      libgssrpc4t64 \
      libk5crypto3 \
      libkadm5clnt-mit12 \
      libkadm5srv-mit12 \
      libkdb5-10t64 \
      libkrb5-3 \
      libkrb5-dev \
      libkrb5support0 \
      liblastlog2-2 \
      liblcms2-2 \
      liblcms2-dev \
      liblzma-dev \
      liblzma5 \
      libmount-dev \
      libmount1 \
      libnghttp2-14 \
      libnghttp2-dev \
      libpcre2-16-0 \
      libpcre2-32-0 \
      libpcre2-8-0 \
      libpcre2-dev \
      libpcre2-posix3 \
      libperl5.40 \
      libraw23t64 \
      librsvg2-2 \
      librsvg2-common \
      librsvg2-dev \
      libsmartcols1 \
      libsqlite3-0 \
      libsqlite3-dev \
      libssh2-1-dev \
      libssh2-1t64 \
      libsystemd0 \
      libtasn1-6 \
      libtasn1-6-dev \
      libudev1 \
      libunbound8 \
      libuuid1 \
      libvips42t64 \
      libxml2 \
      libxml2-dev \
      linux-libc-dev \
      login \
      mount \
      perl \
      perl-base \
      perl-modules-5.40 \
      util-linux \
      uuid-dev \
      xz-utils \
    && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Grover needs Node and Chromium in development, CI images, and deployed workers.
# Debian supplies Chromium for both amd64 and arm64; Puppeteer uses this binary.
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends chromium fonts-liberation python3-venv && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV PDF_PYTHON=/opt/emmy/pdf-venv/bin/python \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    GROVER_NO_SANDBOX=true \
    XDG_CONFIG_HOME=/rails/tmp/chromium-config \
    XDG_CACHE_HOME=/rails/tmp/chromium-cache

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
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      npm \
      pkg-config \
    && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy application code
COPY . .

RUN npm ci && \
    python3 -m venv /opt/emmy/pdf-venv && \
    /opt/emmy/pdf-venv/bin/pip install --no-cache-dir --require-hashes -r lib/pdf/requirements.txt

##########################################################################################
# DEV: Used for development and test
##########################################################################################
FROM build AS dev

ENV RAILS_ENV="development"

# Set the tmp dir to the writeable tmp volume
ENV TMPDIR="/rails/tmp"

# Install packages needed for development
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      postgresql-client-17 \
      graphviz=2.42.4-3 \
      && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN mkdir -p /rails/tmp /docs/app/rendered && \
    echo 0 > /docs/app/rendered/.database-diagram-schema-version

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

# Set the working directory so when we attach a shell we're in the project's root directory
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
# Keep libvips unpinned so this stage preserves security updates from BASE.
#
# To debug a missing package version (i.e. if one of these versions gets
# superceded in the upstream package repo), run:
#
#   docker run -ti registry.docker.com/library/ruby:3.4.9 bash
#   apt-get install [package]
#
# and notice the version that was installed.
# hadolint ignore=DL3008
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        libgpgme11t64=1.24.2-3 \
        libvips42t64 \
        postgresql-client-17 \
        python-is-python3=3.13.3-1 \
        python3-venv=3.13.5-1 \
        python3-pip=25.1.1+dfsg-1 \
        && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install custom database scripts
COPY bin/db-migrate /usr/bin/
COPY bin/db-drop-schema /usr/bin/

# Copy built artifacts: gems, application, binary dependencies
COPY --from=release-build /usr/local/bundle /usr/local/bundle
COPY --from=release-build /rails /rails
COPY --from=release-build /opt/emmy/pdf-venv /opt/emmy/pdf-venv

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
