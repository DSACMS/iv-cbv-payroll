# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.0


##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

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

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config npm

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

# Install npm packages
RUN npm install


##########################################################################################
# DEV: Used for development and test
##########################################################################################
FROM build as dev

ENV RAILS_ENV="development"

# Install packages needed for development
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y postgresql-client graphviz && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems for development
COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without production && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

CMD ["./bin/dev"]


##########################################################################################
# RELEASE-BUILD: Throw-away build stage for RELEASE
##########################################################################################
FROM build as release-build

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
FROM base as release

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends unzip python3-venv python-is-python3 curl libvips postgresql-client libjpeg-dev wkhtmltopdf && \
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
RUN cp /usr/bin/wkhtmltopdf /rails/bin/wkhtmltopdf

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
USER rails:rails
VOLUME /rails/tmp

# Start the server
CMD ["./bin/rails", "server"]
