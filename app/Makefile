.PHONY : \
	release-build \
	test

.DEFAULT_GOAL := help

# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.
# Based off of https://stackoverflow.com/questions/10858261/how-to-abort-makefile-if-variable-not-set
check_defined = \
	$(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
	$(if $(value $1),, \
		$(error Undefined $1$(if $2, ($2))$(if $(value @), \
			required by target `$@')))

##################################################
# Constants
##################################################

APP_NAME := app-rails

# Support other container tools like `finch`
ifdef CONTAINER_CMD
	DOCKER_CMD := $(CONTAINER_CMD)
else
	DOCKER_CMD := docker
endif

# By default, all rails commands will run inside of the docker container
# if you wish to run this natively, add RAILS_RUN_APPROACH=local to your environment vars
# You can set this by either running `export RAILS_RUN_APPROACH=local` in your shell or add
# it to your ~/.zshrc file (and run `source ~/.zshrc`)
ifeq "$(RAILS_RUN_APPROACH)" "local"
BUNDLE_EXEC_CMD := bundle exec
else
BUNDLE_EXEC_CMD := $(DOCKER_CMD) compose run $(DOCKER_EXEC_ARGS) --rm $(APP_NAME) bundle exec
endif

ifeq "$(RAILS_RUN_APPROACH)" "local"
RAILS_RUN_CMD := bundle exec rails
else
RAILS_RUN_CMD := $(DOCKER_CMD) compose run $(DOCKER_EXEC_ARGS) --rm $(APP_NAME) bundle exec rails
endif

ifeq "$(RAILS_RUN_APPROACH)" "local"
RUBY_RUN_CMD :=
else
RUBY_RUN_CMD := $(DOCKER_CMD) compose run $(DOCKER_EXEC_ARGS) --rm $(APP_NAME)
endif

# Docker user configuration
# This logic is to avoid issues with permissions and mounting local volumes,
# which should be owned by the same UID for Linux distros. Mac OS can use root,
# but it is best practice to run things as with least permission where possible

# Can be set by adding user=<username> and/ or uid=<id> after the make command
# If variables are not set explicitly: try looking up values from current
# environment, otherwise fixed defaults.
# uid= defaults to 0 if user= set (which makes sense if user=root, otherwise you
# probably want to set uid as well).
ifeq ($(user),)
RUN_USER ?= $(or $(strip $(USER)),nodummy)
RUN_UID ?= $(or $(strip $(shell id -u)),4000)
else
RUN_USER = $(user)
RUN_UID = $(or $(strip $(uid)),0)
endif

export RUN_USER
export RUN_UID

##################################################
# Setup
##################################################


.env: local.env.example
	@([ -f .env ] && echo ".env file already exists, but local.env.example is newer (or you just switched branches), check for any updates" && touch .env) || cp local.env.example .env

init-container: ## Initialize the project for running in a container
init-container: .env build init-db

init-native: ## Initialize the project for running natively
init-native: .env deps-native init-db

init-db: ## Initialize the project database
init-db: .env db-up wait-on-db db-migrate db-test-prepare db-seed

deps-native: ## Install dependencies
	bundle install
	npm install

clean-native: ## Remove native installs
	rm -rf node_modules
	git checkout node_modules/.keep
	rm -rf app/builds
	git checkout app/assets/builds/.keep
	rm -rf tmp/*
	rm -rf vendor/bundle
	git checkout vendor/bundle/.keep

clean-container: ## Remove just the container related volumes
	$(DOCKER_CMD) compose down --volumes $(APP_NAME)

##################################################
# Build & Run
##################################################

release-build:
	docker buildx build \
		--platform=linux/amd64 \
		--build-arg RUN_USER=$(RUN_USER) \
		--build-arg RUN_UID=$(RUN_UID) \
		$(OPTS) \
		.

build: ## Build the Docker container
	$(DOCKER_CMD) compose build $(APP_NAME)

clean-volumes: ## Remove container volumes (which includes the DB state)
	$(DOCKER_CMD) compose down --volumes

start-native: ## Run Rails natively, outside Docker
start-native: db-up
	./bin/dev

start-container: ## Run within Docker
	$(DOCKER_CMD) compose up $(APP_NAME)

stop-containers: ## Stop Docker
	$(DOCKER_CMD) compose down

##################################################
# Database
##################################################

db-up: ## Run just the database container
	$(DOCKER_CMD) compose up --remove-orphans --detach database

db-migrate: ## Run database migrations
	$(RAILS_RUN_CMD) db:migrate

db-test-prepare: ## Prepare the test database
	$(RAILS_RUN_CMD) db:test:prepare

db-seed: ## Seed the database
	$(RAILS_RUN_CMD) db:seed

db-reset: ## Reset the database
	$(RAILS_RUN_CMD) db:reset

db-console: ## Access the rails db console
	$(RAILS_RUN_CMD) dbconsole

wait-on-db:
	./bin/wait-for-local-postgres.sh

##################################################
# Testing
##################################################

test: ## Run the test suite
	$(RUBY_RUN_CMD) ./bin/rspec

##################################################
# Lint & Formatting
##################################################

lint: ## Run the linter with auto-fixing
	$(RUBY_RUN_CMD) ./bin/rubocop -a

lint-ci: ## Run the linter, but don't fix anything
	$(RUBY_RUN_CMD) ./bin/rubocop

##################################################
# Rails
##################################################

rails-console:
	$(RAILS_RUN_CMD) console

rails-routes:
	$(RAILS_RUN_CMD) routes

rails-generate:
	$(RAILS_RUN_CMD) generate $(GENERATE_COMMAND)

new-policy:
	@:$(call check_defined, MODEL, the name of model to generate)
	$(RAILS_RUN_CMD) generate pundit:policy $(MODEL)

locale:
	@:$(call check_defined, MODEL, the name of model to generate)
	$(RAILS_RUN_CMD) generate locale $(MODEL)

new-admin-model:
	@:$(call check_defined, MODEL, the name of model to generate)
	$(RAILS_RUN_CMD) generate administrate:dashboard $(MODEL)

clear-cache:
	$(RAILS_RUN_CMD) tmp:clear
	$(RAILS_RUN_CMD) assets:clean

precompile-assets:
	SECRET_KEY_BASE_DUMMY=1
	$(RAILS_RUN_CMD) assets:precompile

##################################################
# Miscellaneous Utilities
##################################################

help: ## Prints the help documentation and info about each command
	@grep -Eh '^[/a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
