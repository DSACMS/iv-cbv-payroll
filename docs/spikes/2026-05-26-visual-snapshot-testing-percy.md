# Percy visual snapshot testing POC

The code demonstrates a few different Percy integration shapes. The goal is to show what works locally, not to say every pattern here should become the long term default.

## Files added

- `app/.percy.yml`, automatically picked up by Percy CLI
- `app/percy/lookbook-snapshots.yml`
- `app/spec/e2e/visual_snapshots_spec.rb`
- one guarded Percy snapshot inside `app/spec/e2e/activity_hub_spec.rb`

This also adds `percy-capybara` to the test group.

The POC intentionally does not add `@percy/cli` to `package.json`. Use `npx @percy/cli` for the local demo.

## Prerequisites

- Access to the Nava Percy organization
- A Percy project token exported as `PERCY_TOKEN`
- `bundle install` has been run

## Demo 1: Lookbook URL snapshots

Start Rails:

```bash
cd app
bin/dev
```

In a second terminal:

```bash
cd app
npx @percy/cli snapshot percy/lookbook-snapshots.yml
```

This snapshots the URLs listed in `app/percy/lookbook-snapshots.yml`:

- `Lookbook / Table / Multi-column`
- `Lookbook / Activity card / Employment`
- `Lookbook / Activity flow progress / Review completed`

## Demo 2: Dedicated Capybara visual spec

Run:

```bash
cd app
PERCY_VISUAL_RUN=1 E2E_RUN_TESTS=1 npx @percy/cli exec -- bin/rspec spec/e2e/visual_snapshots_spec.rb
```

This snapshots:

- `CBV applicant information`
- `Activity Hub empty state`

The visual spec is gated so it does not run real Percy snapshots by default.

To confirm the default behavior:

```bash
cd app
E2E_RUN_TESTS=1 bin/rspec spec/e2e/visual_snapshots_spec.rb
```

Expected behavior: both examples are pending unless `PERCY_VISUAL_RUN=1` is set.

## Demo 3: Inline snapshot in an existing E2E flow

This shows that Percy can also be added at an existing `verify_page(...)` checkpoint in a normal E2E flow.

Run:

```bash
cd app
PERCY_VISUAL_RUN=1 E2E_RUN_TESTS=1 npx @percy/cli exec -- bin/rspec spec/e2e/activity_hub_spec.rb:15
```

Snapshot:

- `E2E Activity Hub empty state`

This is useful as a demo of the integration option. I would still be careful about using this as the default long-term pattern, because it can mix visual coverage into behavior-focused E2E specs.

## Out of scope for this POC

- GitHub Actions integration
- CMS Cloud changes
- Deployed review app snapshots
- Broad route coverage
- Percy baseline ownership decisions
