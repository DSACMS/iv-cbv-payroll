## [FFS-4421](https://jiraent.cms.gov/browse/FFS-4421)

## Changes
- Update `app/bin/will-deploy` so the deployment Slack message links to the new launcher URL: link text changed from "Launch the demo" to "Open the launcher", and URL changed from `https://la-verify-demo.navapbc.cloud/demo` to `https://verify-demo.navapbc.cloud/launcher`.

## Testing instructions
1. From `app/`, run `bin/will-deploy` (you can interrupt before completion if you don't want to actually categorize changes — the output line is built from a static string and visible by inspecting the script).
2. Confirm the generated Slack message contains `*[Open the launcher →](https://verify-demo.navapbc.cloud/launcher)*` instead of the old `Launch the demo` link.

## Acceptance testing
Tag product and design in Slack for acceptance: @emmy-acceptance-testers

- [x] No acceptance testing needed
  * This change will not affect the user experience (bugfix, dependency updates, etc.)
- [ ] Acceptance testing prior to merge
  * This change can be verified visually via screenshots attached below or by sending a link to a local development environment to the acceptance tester
  * Acceptance testing should be done by **design** for visual changes, **product** for behavior/logic changes, **or both** for changes that impact both.
- [ ] Acceptance testing in PR Environment
  * This change can be verified in a PR environment. Run [this Github Action](https://github.com/DSACMS/iv-cbv-payroll/actions/workflows/ci-app-pr-environment-checks.yml) with the existing PR and most recent git sha.
- [ ] Acceptance testing after merge
  * This change is hard to test locally, so we'll test it in the demo environment (deployed automatically after merge.)
  * Make sure to notify the team once this PR is merged so we don't inadvertently deploy the unaccepted change to production.

<!-- begin PR environment info -->
## Preview environment
- Link to launcher: https://p-1726.navapbc.cloud/launcher/advanced
- Deployed commit: TBD
<!-- end PR environment info -->

## AI Agent Notes
### Assumptions Made
1. The only place that needed updating was `app/bin/will-deploy` line 153 — a repo-wide grep for `la-verify-demo` and `Launch the demo` returned no other matches.
2. The arrow character (`→`) and surrounding Slack markdown formatting should be preserved exactly; only the link text and URL were changed.
3. The untracked `REVIEW.md` file at the repo root is unrelated to this ticket and was left alone.

### Open questions
1. None.
