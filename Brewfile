# Brewfile
# add any dependencies that must be installed from homebrew here

# Ruby version manager
brew "rbenv"

# NodeJS version manager
brew "nodenv"

# cloud.gov RDS is on postgres 12
brew "postgresql@12", link: true

# docker is used for building images for deployment, and in the bin/with-server script
cask "docker"
brew "dockerize"

# helper scripts for creating new ADRs
brew "adr-tools"

# chromedriver for integration tests
cask "chromedriver"

# used by rails-erd documentation tool
brew "graphviz"

# used in terraform/create_space_deployer.sh
brew "jq"

# queue for sidekiq jobs
brew "redis"

# ngrok local tunnel to receive webhooks
cask "ngrok"

# Terraform version manager for infrastructure
brew "tfenv"

# AWS command-line utilities necessary for deploying and operations
brew "awscli"
cask "session-manager-plugin"
