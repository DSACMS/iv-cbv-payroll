---
name: worktree-create
description: Use this script to make a worktree for a branch of the "app" subdirectory in the "iv-cbv-payroll" repository. This skill will help you set up the application.
---
<!-- This was inspired by: https://github.com/obra/superpowers/blob/main/skills/using-git-worktrees/SKILL.md -->

# Creating a Worktree for iv-cbv-payroll

## 1. Check for existing worktree directory
Check for an existing `.worktrees` directory at the top-level of this repo, or create it.

```
ls -d .worktrees 2>/dev/null     # Preferred (hidden)
```

## 2. Create the worktree for the given branch

```
project=$(basename "$(git rev-parse --show-toplevel)")

# Determine path based on chosen location
# For project-local: path=".worktrees/$BRANCH_NAME"

git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

If BRANCH_NAME is not provided, look for user instructions in their Agent configuration about how they name their branches. Otherwise, fall back to naming it with "$username/$ticket-$title", where $username is the user's username, $ticket is the ticket the user is asking you to work on, and $title is a quick summary of the title with filler words removed.

## 3. Project Setup
Do all of these steps in the `app` subdirectory:

### Setup Step 1: Initialize `.env.local`
Copy the `.env.local` file from the top-level repository's `app` subdirectory (outside the worktree) into the worktree's `app` subdirectory.

### Setup Step 2: Create a custom database for this worktree
Add to the worktree's `.env.local` file these values (for example, for ticket/branch FFS-1234):

```
DB_NAME=iv_cbv_payroll_development_ffs_1234
DB_TEST_NAME=iv_cbv_payroll_test_ffs_1234
```

Then, run `bin/rails db:setup`.

### Setup Step 3: Install dependencies and build assets
```
bin/update
npm install --cache /private/tmp/iv-cbv-payroll-npm-cache
npm run build:css
npm run build
```
