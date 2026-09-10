# Release Process

How Emmy App gets from a merge on `main` to a tagged release running in
production.

- [Release schedule](#release-schedule)
- [Release roles](#release-roles)
- [Production deployment steps](#production-deployment-steps)
- [Manual GitHub release creation](#manual-github-release-creation)

## Release schedule

**Dev** deploys automatically on every merge to `main`.

**Production** deploys are run regularly on **Tuesdays** by the On Call
Engineer, and additionally as needed. Production deploys should be discussed
with the team and scheduled to minimize disruption to live pilots.

## Release roles

| Role | Who |
| --- | --- |
| Release engineer | Any engineer on the Emmy Product team |
| Approvers | Jake or Jacob |
| Communicate changes to pilot partners (if needed) | see [versioning.md](/versioning.md) if you're unsure whether comms are needed |

CMS approvers for deploy testing: **Worrell, Jacob (CMS/USDS)** and
**Shilling, Jake (CMS/OHTP)**.

## Production deployment steps

### 1. Plan the deploy

Monday morning, or at least 24 hours before the intended deploy, plan when the
deploy will go out and what it will contain.

Start a **deployment Slack thread** and use it to coordinate every step below.

### 2. Announce what will deploy

From the `app/` directory on an up-to-date `main`, run
[`bin/will-deploy`](../app/bin/will-deploy) and post the results in
**#dsac-shared-emmy-platform**. It automatically tags `@emmy-platform`.

> ⚠️ **Note the GitHub SHA in the will-deploy message.** That is the version to
> test and deploy — every later step refers back to it.

Save a public version of the release notes now, following
[Manual GitHub release creation](#manual-github-release-creation) below. You'll
paste this into the GitHub release after the deploy.

### 3. Get CMS approval

1. Contact the CMS approvers in Slack with the deploy output.
2. Allow them a **full 24 hours** to review. Do not send reminders or ask for
   updates during that window. After 24 hours, a gentle ping is fine.
3. If there is an active pilot, ask the CMS approvers whether comms to pilot
   partners are necessary. If so, the pilot chair coordinates comms.

### 4. Decide the release number

Classify the release **MAJOR**, **MINOR**, or **PATCH** using the rubric in
[versioning.md](./versioning.md). The tiebreaker: *could a state's existing
training material now mislead someone?* If yes, it's MAJOR.

While Emmy App is pre-1.0, a MAJOR-tier release bumps the middle digit
(`0.1.0` → `0.2.0`) and a MINOR- or PATCH-tier release bumps the last digit
(`0.1.0` → `0.1.1`).

Then, in a PR merged to `main` before the deploy:

1. Update [`app/version.txt`](../app/version.txt) to the new version.
2. Update the `"version"` field in [`code.json`](../code.json) to match.
3. Annotate in [`CHANGELOG.md`](../CHANGELOG.md) breaking changes, if any,
   which necessitated the major version bump.

### 5. Smoke test in Dev

Once CMS approval has been given, on the following day the deploying engineer
(or a designee) runs through this process:

1. Announce in **#dsac-shared-emmy-eng** to hold off on merges while testing
   proceeds.
2. Make sure nothing is currently deploying to dev — check the
   [Deploy App workflow runs](https://github.com/DSACMS/iv-cbv-payroll/actions/workflows/cd-app.yml)
   for running "Deploy main to App Dev" jobs. If there is one, wait for it to
   finish.
3. Make sure the approved version is available to smoke test in dev. If it
   isn't, deploy it.

   > Redeploying a previous SHA to dev could cause issues if there were
   > database migrations in between.
4. Execute the tests in the **Smoke Test Criteria** page in Confluence.
5. Verify that the version you were testing hasn't changed. If it has, decide
   whether to:
   - smoke test the newer SHA in dev anyway, or
   - re-request approval for the newer SHA as a new deploy.

   > In the future we hope to use ephemeral environments for this, so we can
   > spin up an environment per deploy for smoke testing.
6. Decide whether to deploy, and notify the Slack thread.
7. Coordinate resolution of any test failures.

### 6. Release to Demo

1. Run the **Deploy App** GitHub Action in the `demo` environment, specifying
   the deploy SHA.
2. Notify the Slack thread that the demo deploy is in progress.
3. Monitor New Relic for Demo environment health.
4. Monitor **#ffs-cbv-alerts** for new system errors related to the deploy.

### 7. Release to Production

1. Run the **Deploy App** GitHub Action in the `prod` environment, specifying
   the deploy SHA.
2. Notify the Slack thread that the prod deploy is in progress.
3. Monitor New Relic for Prod environment health.
4. Monitor **#ffs-cbv-alerts** for new system errors related to the deploy.

### 8. Release to CMS UAT

Trigger the **Deploy to CMS** action with `uat` as the environment and the
current deploy SHA.

### 9. Post-deployment

1. Notify the Slack thread that the production deploy is complete.
2. Add a release in GitHub using the text you saved in step 2, tagged with the
   version number decided in step 4. See
   [Manual GitHub release creation](#manual-github-release-creation).
3. **Parekh, Allyse (CMS/CTR)** and **Gupta, Rutvika (CMS/CTR)** notify state
   partners of the deployment via email, if needed.
4. If the deploy fixed issues that prevented reports from syncing, consider
   re-triggering them.

## Manual GitHub release creation

Releases are published manually in GitHub using the output of the
[`app/bin/will-deploy`](../app/bin/will-deploy) script as the release body.

### Generate the release notes

From the `app/` directory on an up-to-date `main`, run:

```bash
bin/will-deploy
```

The script will:

1. `git fetch` and compare `origin/main` against the SHA currently running in
   production (read from `https://snap-income-pilot.com/health`).
2. Walk every commit between production and `main`, printing the commit
   subject and a link to the PR or commit on GitHub.
3. Prompt you to categorize each non-bot commit:
   - `b` — user-facing change to **both** Emmy Income and Emmy CE
   - `i` — user-facing change to **Emmy Income** only
   - `e` — user-facing change to **Emmy CE** only
   - `o` — Other / Maintenance (not user-facing)
   - `s` — Skip (omit from the notes)

   Commits authored by `[bot]` accounts (e.g. Dependabot) are auto-categorized
   as Other/Maintenance.
4. Assemble a formatted message with the deploy SHA, demo link, per-area
   change lists, and a link to the full diff on GitHub.
5. Copy the message to your clipboard and print it to the terminal.

### Review the PR titles before publishing

> ⚠️ **Check the language in PR titles for anything not appropriate for public
> viewing.** The will-deploy output is built directly from commit subjects
> (which include the merged PR titles), and the GitHub release page is public.
> Look for internal-only jargon, customer or partner names that shouldn't be
> disclosed, joke titles, or anything that reveals non-public
> security details. Edit the text before pasting it into the release body.

### Create the GitHub release

1. Go to <https://github.com/DSACMS/iv-cbv-payroll/releases/new>.
2. **Tag**: create a new `v<version>` tag (e.g. `v0.1.0`) on `main`, pointing at
   the deploy SHA — the short SHA from the first line of the will-deploy output
   is the commit being released. The version must match `app/version.txt` on
   that commit.

   The `deploy/prod/<timestamp>` tags created by the deploy pipeline are deploy
   markers, not releases. Don't use them as the release tag.
3. **Title**: `v<version>`, optionally with a short summary of the deploy.
4. **Description**: paste the will-deploy output (with any edits from the
   review step), with the release tier (MAJOR / MINOR / PATCH) on the first
   line. GitHub's Markdown renderer handles the Jira and PR links the script
   emits.
5. Leave "Set as the latest release" checked.
6. Click **Publish release**.

## Notify states on a MAJOR release

MAJOR means a state's training materials or integration may no longer match the
application. Send the notification with before/after screenshots and enough lead
time for states to update their materials. MINOR and PATCH releases ship on the
normal cadence and appear in the changelog only.
