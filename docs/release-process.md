# Manual GitHub Release Process

Releases are published manually in GitHub using the output of the
[`app/bin/will-deploy`](../app/bin/will-deploy) script as the release body.

## 1. Decide the version number

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

## 2. Generate the release notes

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

## 3. Review the PR titles before publishing

> ⚠️ **Check the language in PR titles for anything not appropriate for public
> viewing.** The will-deploy output is built directly from commit subjects
> (which include the merged PR titles), and the GitHub release page is public.
> Look for internal-only jargon, customer or partner names that shouldn't be
> disclosed, joke titles, or anything that reveals non-public
> security details. Edit the text before pasting it into the release body.

## 4. Create the GitHub release

1. Go to <https://github.com/DSACMS/iv-cbv-payroll/releases/new>.
2. **Tag**: create a new `v<version>` tag (e.g. `v0.1.0`) on `main`, pointing at
   the deploy SHA — the short SHA from the first line of the will-deploy output
   is the commit being released. The version must match `app/version.txt` on
   that commit.

   The `deploy/prod/<timestamp>` tags created by the deploy pipeline are deploy
   markers, not releases. Don't use them as the release tag.
3. **Title**: `v<version>`, optionally with a short summary of the deploy.
4. **Description**: paste the will-deploy output (with any edits from step 3),
   with the release tier (MAJOR / MINOR / PATCH) on the first line. GitHub's
   Markdown renderer handles the Jira and PR links the script emits.
5. Leave "Set as the latest release" checked.
6. Click **Publish release**.

## 5. Notify states on a MAJOR release

MAJOR means a state's training materials or integration may no longer match the
application. Send the notification with before/after screenshots and enough lead
time for states to update their materials. MINOR and PATCH releases ship on the
normal cadence and appear in the changelog only.
