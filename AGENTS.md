# Overview

This repo is a monorepo structure, with top-level directories containing different types of code for different parts of the system. We currently use:
* `app` - The Ruby on Rails application implementing the Income Verification as a Service (IVaaS) project. See the section below about the `app` subdirectory.
* `infra` - Terraform code related to building our environments.
* `docs` - Documentation about the system.

# General Project Instructions
* Add test coverage whenever possible.
* Always run tests after writing them. Verify that they pass before completing your task.
