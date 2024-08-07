# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.4


##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

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
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential=12.9 \
    git=1:2.39.2-1.1 libpq-dev=15.7-0+deb12u1 pkg-config=1.8.1-1 \
    npm=9.2.0~ds1-1

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
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y postgresql-client=15+248 \
        graphviz=2.42.2-7+b3 \
        wkhtmltopdf=0.12.6-2+b1 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems for development
COPY Gemfile Gemfile.lock ./

RUN gem install bundler --no-document -v ${BUNDLER_VERSION} && \
    bundle config set --local without production && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

CMD ["./bin/dev"]


##########################################################################################
# RELEASE-BUILD: Throw-away build stage for RELEASE
##########################################################################################
FROM build AS release-build

# Install application gems for production
COPY Gemfile Gemfile.lock ./
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

# Set the tmp dir to the writeable tmp volume
ENV TMPDIR="/rails/tmp"

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends unzip=6.0-28 \
        python3-venv=3.11.2-1+b1 \
        python-is-python3=3.11.2-1+deb12u1 \
        curl=7.88.1-10+deb12u6 \
        libvips42=8.14.1-3+deb12u1 \
        postgresql-client=15+248 \
        linux-libc-dev=6.1.99-1 \
        wkhtmltopdf=0.12.6-2+b1 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm -rf ./awscli-bundle awscli-bundle.zip

# Remove base rexml for GHSA-4xqq-m2hx-25v8
RUN gem uninstall -i /usr/local/lib/ruby/gems/3.3.0 debug && \
    gem uninstall -i /usr/local/lib/ruby/gems/3.3.0 rss && \
    gem uninstall -i /usr/local/lib/ruby/gems/3.3.0 rexml

# Install custom db migrate script
COPY bin/db-migrate /usr/bin/

# Copy built artifacts: gems, application, binary dependencies
COPY --from=release-build /usr/local/bundle /usr/local/bundle
COPY --from=release-build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
USER rails:rails
VOLUME /rails/tmp

# Start the server
CMD ["./bin/rails", "server"]
