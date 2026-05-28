# Manual GitHub Release Process

Releases are published manually in GitHub using the output of the
[`app/bin/will-deploy`](../app/bin/will-deploy) script as the release body.

## 1. Generate the release notes

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

## 2. Review the PR titles before publishing

> ⚠️ **Check the language in PR titles for anything not appropriate for public
> viewing.** The will-deploy output is built directly from commit subjects
> (which include the merged PR titles), and the GitHub release page is public.
> Look for internal-only jargon, customer or partner names that shouldn't be
> disclosed, joke titles, or anything that reveals non-public
> security details. Edit the text before pasting it into the release body.

## 3. Create the GitHub release

1. Go to <https://github.com/DSACMS/iv-cbv-payroll/releases/new>.
2. **Tag**: create a new tag on `main` for the deploy SHA (the short SHA from
   the first line of the will-deploy output is the commit being released).
3. **Title**: the release tag, or a short summary of the deploy.
4. **Description**: paste the will-deploy output (with any edits from step 2).
   GitHub's Markdown renderer handles the Jira and PR links the script emits.
5. Leave "Set as the latest release" checked.
6. Click **Publish release**.
