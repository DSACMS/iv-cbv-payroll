# Code Review: FFS-4421 — Update will-deploy script to output new launcher URL

## Scope

One commit on this branch (`cb5b9dd3`) touching two files:

- `app/bin/will-deploy` — one-line change to the Slack message string (line 153).
- `PR_DESCRIPTION.md` — new file at repo root (37 lines, all prose).

Net: +38 / -1 lines.

## Summary

The functional change is a low-risk, single-line string update in a developer-facing
deploy helper. It does what the ticket title says. The main concerns are not with the
substantive code change but with (a) the lack of any test coverage for the script
generally, and (b) the addition of `PR_DESCRIPTION.md` to the repo, which appears to
be an unintentional artifact.

## Correctness

### `app/bin/will-deploy:153`

```ruby
- output << "🧪 *[Launch the demo →](https://la-verify-demo.navapbc.cloud/demo)*\n\n"
+ output << "🧪 *[Open the launcher →](https://verify-demo.navapbc.cloud/launcher)*\n\n"
```

Verified:

- **Domain exists.** `verify-demo.navapbc.cloud` is the configured demo domain — see
  `infra/app/app-config/dev.tf:8` (`domain_name = "verify-demo.navapbc.cloud"`) and
  `infra/project-config/networks.tf:12`.
- **Path exists.** `/launcher` is a defined Rails route in
  `app/config/routes.rb:151` (`get "/launcher", to: "demo_launcher#launcher"`).
- **No stale references to the old URL.** A repo-wide grep for `la-verify-demo`
  returns no hits in source code; the only remaining mention is in the new
  `PR_DESCRIPTION.md` (quoting itself). Confirms the assumption in the PR
  description that this was the only call site.
- **Old URL was already aliased.** `app/config/routes.rb:155` defines
  `get "/demo", to: redirect("/launcher")`, so the previous deploy link would
  still have redirected correctly. This is reassuring context — there was no
  user-visible breakage before this change, and the change brings the link in
  line with how the page is referenced everywhere else (e.g.
  `bin/update-pr-environment:66`, `PR_DESCRIPTION.md:26`).
- **Markdown formatting preserved.** Bold (`*…*`), emoji prefix (`🧪`), arrow
  character (`→`), and trailing `\n\n` are unchanged. The Slack Cmd+Shift+F
  rendering should be identical in structure to before.

No correctness issues found in the line itself.

### Surrounding code (not changed, noted for context)

Line 152 still uses `current_sha[0, 7]` for the deploy message and line 169
uses the same slicing pattern for the diff comparison. These are unaffected
by this change.

## Test coverage

This is the main weakness.

- **No automated test for the Slack message output.** `app/bin/will-deploy:93–100`
  has a `--test` mode, but it only exercises `linkify_jira`. The hardcoded
  launcher URL on line 153 is not asserted anywhere. A regression that, say,
  drops the link entirely or breaks the bold formatting would only be caught
  the next time someone runs `bin/will-deploy` for real.
- **No test that the URL actually resolves.** Reasonable to skip — this is a
  developer script, not production code — but worth noting that the URL could
  silently rot if `/launcher` were removed or renamed in `routes.rb`.
- **Manual testing path is documented** in `PR_DESCRIPTION.md` (run the script
  and inspect the output). That is adequate for a one-line string change.

Recommendation (optional, not blocking): a tiny RSpec or shell test that
shells out to the script with stubbed git/HTTP responses and asserts the
expected line appears. Likely overkill for a deploy helper, but the
zero-coverage status is worth mentioning.

## Edge cases

There are essentially none for this change — it is a literal string
replacement with no branching, interpolation, or input handling involved.
A few observations on the surrounding script that are not part of this
diff but worth flagging:

- `app/bin/will-deploy:35` — `fetch_production_version` will raise
  uncaught on network failure. Unchanged by this PR.
- `app/bin/will-deploy:76` — `copy_to_clipboard` shells out to `pbcopy`,
  so the script is implicitly macOS-only. Unchanged.
- `app/bin/will-deploy:43` — uses `prod..current_sha` as a git range; if
  the prod SHA is ever ahead of `origin/main`, this yields an empty list
  silently. Unchanged.

None of these are introduced or aggravated by this PR.

## Security

No security concerns.

- The change is a static string in a developer helper script that runs
  locally on a maintainer's machine and writes to the macOS clipboard.
- The new URL is HTTPS, points to a domain already in use by this project
  (confirmed against `infra/app/app-config/dev.tf:8`), and is not a
  user-controlled value.
- No new input parsing, no new shell-outs, no new network calls, no
  secrets touched.

## Other observations

### `PR_DESCRIPTION.md` should probably not be committed

`PR_DESCRIPTION.md` was added at the repo root. PR descriptions belong in
the GitHub PR body, not in the working tree:

- It will be carried as committed history forever.
- It contains placeholder content that will go stale immediately
  (`PR_DESCRIPTION.md:26` references PR environment `p-1726` and
  `Deployed commit: TBD`).
- It documents AI agent provenance ("AI Agent Notes", "Assumptions Made",
  "Open questions") that is more appropriate for a PR comment than a
  source-controlled artifact.
- The file's own "Assumptions Made" section (line 33) notes
  `REVIEW.md` is untracked and "unrelated to this ticket and was left
  alone" — this is the kind of meta-commentary that belongs in the PR
  body, not in a tracked file.

**Recommendation:** move the contents into the GitHub PR body and drop
`PR_DESCRIPTION.md` from the commit, or add it to `.gitignore` if the
intent is to use it as a scratch file.

### Commit hygiene

The single commit `FFS-4421: Update will-deploy script to point to new launcher`
follows the project's convention from `CLAUDE.md`
("Brief sentence-case subject, prefix with ticket number if applicable").
Good.

### Untracked `REVIEW.md`

There is an untracked `REVIEW.md` file at the repo root (per `git status`).
Not part of this branch's diff, but flagging for cleanup so it does not
get accidentally committed in a future change.

## Verdict

The substantive change (`app/bin/will-deploy:153`) is **safe to merge**.
It is one line, correctly targets an existing route on an existing domain,
and replaces a URL that already redirected to the same destination.

Before merging, I would:

1. **Remove `PR_DESCRIPTION.md` from the commit** (move the content to the
   GitHub PR body).
2. Optionally, decide whether the untracked `REVIEW.md` should be added
   to `.gitignore`.

No correctness, edge-case, or security blockers.
