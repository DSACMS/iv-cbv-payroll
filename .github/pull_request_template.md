<!-- ---------------------------------------------------------------------------
Some examples of good, understandable PR titles:

FFS-1111: Fix missing translation on /entry page
FFS-2222: Implement invitation reminder emails

(The title of the pull request will be used in the eventual deploy log - so it's helpful to format the title to be understandable by other disciplines if possible.)
--------------------------------------------------------------------------- -->
## Ticket

Resolves [FFS-XXXX](https://jiraent.cms.gov/browse/FFS-XXXX).


## Changes
<!-- What was added, updated, or removed in this PR. -->


## Context for reviewers
<!-- Anything you'd like other engineers on the team to know. -->


## Acceptance testing
<!-- Check one: -->

- [ ] No acceptance testing needed
  * This change will not affect the user experience (bugfix, dependency updates, etc.)
- [ ] Acceptance testing prior to merge
  * This change can be verified visually via screenshots attached below or by sending a link to a local development environment to the acceptance tester
  * Acceptance testing should be done by **design** for visual changes, **product** for behavior/logic changes, **or both** for changes that impact both.
- [ ] Acceptance testing after merge
  * This change is hard to test locally, so we'll test it in the demo environment (deployed automatically after merge.)
  * Make sure to notify the team once this PR is merged so we don't inadvertently deploy the unaccepted change to production. (e.g. `:alert: Deploy block! @ffs-eng I just merged PR [#123] and will be doing acceptance testing in demo - please don't deploy until I'm finished!`)

## Infrastructure Changes
<!-- If this PR includes Terraform changes, please provide relevant info. -->

  - [ ] Plan reviewed
  - [ ] Applied in dev before merge
  - [ ] Applied in prod after merge (note any exceptions or special coordination below)

**Risk / Downtime:**
<!-- Note exceptions, potential downtime, or required coordination -->
