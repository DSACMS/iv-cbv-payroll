# Draft Activity Flag Design

## Context

When a user creates an activity in the activity hub but exits before completing the review step, the partially-created record should not appear on the hub or contribute to progress calculations. The current branch (`TIMO/delete-on-close`) solves this by tracking in-progress records in the Rails session and threading exclusion lists through the progress calculator and hub queries. This approach is fragile because:

- Every query site must know about session-based exclusions
- Multi-tab scenarios require a `recover_mismatched_flow` subsystem to reconcile session state
- The progress calculator needs an `exclude:` parameter that callers must remember to pass
- Cleanup happens implicitly when the next activity is created, not when the user leaves

This design replaces the session-based approach with a `draft` boolean on the model itself, so the record carries its own lifecycle state.

## Design

### Core Concept

Add a `draft` boolean column to each activity table and `payroll_accounts`. Records start as drafts. The `save_review` action (or equivalent completion action) publishes them. All display and progress queries filter to published records only.

### Migration

Add `draft` column to all 5 tables with the same definition:

```ruby
add_column :volunteering_activities, :draft, :boolean, default: false, null: false
add_column :job_training_activities, :draft, :boolean, default: false, null: false
add_column :employment_activities, :draft, :boolean, default: false, null: false
add_column :education_activities, :draft, :boolean, default: false, null: false
add_column :payroll_accounts, :draft, :boolean, default: false, null: false
```

All 5 tables use `default: false`. Existing records are backfilled to `false` (published). The activity flow create actions explicitly set `draft: true` when creating new records -- this keeps the migration simple and uniform, and means the CBV flow (which also creates payroll accounts) is unaffected.

### Model Changes

**`Activity` base class** (`app/models/activity.rb`):

```ruby
scope :published, -> { where(draft: false) }

def publish!
  update!(draft: false)
end
```

**`PayrollAccount`** (`app/models/payroll_account.rb`): Add the same scope and method directly (it inherits from `ApplicationRecord`, not `Activity`).

### Controller Changes

#### Create actions: set `draft: true`

Since the DB default is `false`, each activity flow create action explicitly sets `draft: true`:

| Controller | Action | How |
|---|---|---|
| `VolunteeringController` | `create` | Include `draft: true` in `.new()` params |
| `JobTrainingController` | `create` | Include `draft: true` in `.new()` params |
| `EmploymentController` | `create` | Include `draft: true` in `.new()` params |
| `EducationController` | `create_fully_self_attested_activity` | Include `draft: true` in `.new()` params |
| `EducationController` | `create_validated_activity` | Include `draft: true` in `.create()` params |
| `Income::SynchronizationsController` | `track_payroll_account_creation` | `@flow.payroll_accounts.find_by(aggregator_account_id: ...).update!(draft: true)` |

CBV flow create paths don't set `draft: true`, so they get the DB default of `false` -- no changes needed there.

#### Completion actions: call `publish!`

Each activity type's completion action calls `publish!` before redirecting:

| Controller | Action | Call |
|---|---|---|
| `VolunteeringController` | `save_review` | `@volunteering_activity.publish!` |
| `JobTrainingController` | `save_review` | `@job_training_activity.publish!` |
| `EmploymentController` | `save_review` | `@employment_activity.publish!` |
| `EducationController` | `save_review` | `@education_activity.publish!` |
| `Income::PaymentDetailsController` | `update` | `@payroll_account.publish!` |

`publish!` must be called **before** `redirect_to after_activity_path` so the progress calculator (which uses `.published`) includes the just-completed activity in its routing decision.

#### What to remove from `BaseController`

Delete entirely:
- `ACTIVITY_PARAMS` constant
- `recover_mismatched_flow` method and its `before_action`
- `creating_records`, `creating_activity`, `creating_payroll_account`
- `track_creating_activity`, `clear_creating_activity`
- `track_creating_payroll_account`, `clear_creating_payroll_account`
- `destroy_tracked_creating_activity`, `destroy_tracked_creating_payroll_account`

#### Hub controller (`ActivitiesController#index`)

Replace `exclude_from` filtering with `.published`:

```ruby
@community_service_activities = @flow.volunteering_activities.published.order(created_at: :desc)
@work_programs_activities = @flow.job_training_activities.published.order(created_at: :desc)
@education_activities = @flow.education_activities.published.order(created_at: :desc)
@employment_payroll_accounts = @flow.payroll_accounts.published.order(created_at: :desc).select(&:sync_succeeded?)
@employment_activities = @flow.employment_activities.published.order(created_at: :desc)
```

Delete the `exclude_from` private method and the `creating_records` / `@any_visible_activities` logic (use the collections directly).

#### Summary controller (`SummaryController#load_summary_data`)

Add `.published` to all queries as a safety net. By the time a user reaches summary, all their activities should be published, but this prevents accidental inclusion of drafts:

```ruby
@community_service_activities = @flow.volunteering_activities.published.order(created_at: :asc)
@work_programs_activities = @flow.job_training_activities.published.order(created_at: :asc)
@education_activities = @flow.education_activities.published.order(created_at: :asc)
@employment_activities = @flow.payroll_accounts.published.select(&:sync_succeeded?)
```

#### Submit controller

Same treatment: add `.published` to all activity queries.

### Progress Calculator Changes

**File:** `app/services/activity_flow_progress_calculator.rb`

Revert to a single-argument constructor. Use `.published` internally:

```ruby
def initialize(activity_flow)
  @activity_flow = activity_flow
  @volunteering_activities = activity_flow.volunteering_activities.published
  @job_training_activities = activity_flow.job_training_activities.published
  @education_activities = activity_flow.education_activities.published
  @employment_activities = activity_flow.employment_activities.published
end
```

Delete:
- `exclude:` parameter
- `maybe_exclude` method
- `excluded_payroll_account_ids` method
- Exclusion filtering in `validated_account_ids` and `monthly_summaries`

The `progress_calculator` helper in `BaseController` simplifies to:

```ruby
def progress_calculator
  @_progress_calculator ||= ActivityFlowProgressCalculator.new(@flow)
end
```

The `after_activity_path` method no longer needs its own calculator instance -- it can use `progress_calculator` directly, since `publish!` has already been called before `after_activity_path` runs.

### `after_activity_path` Flow

The ordering in `save_review` ensures correctness:

1. `@activity.update(review_params)` -- save user input
2. `@activity.publish!` -- mark as non-draft
3. `redirect_to after_activity_path` -- calculator uses `.published`, now includes this activity

No special handling needed.

### Stale Draft Cleanup

Add a recurring Solid Queue job to delete abandoned drafts:

**Job:** `app/jobs/draft_cleanup_job.rb`

```ruby
class DraftCleanupJob < ApplicationJob
  CUTOFF = 24.hours

  def perform
    cutoff = CUTOFF.ago
    [VolunteeringActivity, JobTrainingActivity, EmploymentActivity, EducationActivity].each do |klass|
      klass.where(draft: true, created_at: ...cutoff).destroy_all
    end
    PayrollAccount.where(draft: true, created_at: ...cutoff).destroy_all
  end
end
```

**Config:** Add to `config/recurring.yml`:

```yaml
draft_cleanup:
  class: DraftCleanupJob
  schedule: every hour
```

### Queries That Should NOT Use `.published`

- **Data retention / redaction:** `DataRetentionService` should redact all records including drafts
- **Individual record lookups by ID** (e.g., `find(params[:id])` in edit/update actions): These are for the user who is actively creating the draft -- they need to see their own record
- **Webhook handlers:** Payroll webhooks write to the record by ID regardless of draft status

### Factory Changes

No factory changes needed -- the DB default is `false`, so all factory-created records are published by default. Tests that specifically test draft behavior will use `draft: true` explicitly.

### Test Changes

- Remove tests for removed methods (`recover_mismatched_flow`, `track_creating_activity`, etc.)
- Update progress calculator specs to remove `exclude:` parameter usage
- Add specs for the `draft`/`published` scopes on Activity and PayrollAccount
- Add specs for `publish!` behavior
- Add specs for `DraftCleanupJob`
- Update hub controller specs to verify drafts are excluded
- Update `save_review` specs to verify `publish!` is called

### Verification Plan

1. **Migration**: Run `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:schema:load`
2. **Tests**: Run `bin/rspec` -- all existing tests should pass (factories default to `draft: false`)
3. **Manual smoke test**:
   - Create a volunteering activity, abandon mid-flow, verify it doesn't appear on hub
   - Create a volunteering activity, complete through review, verify it appears on hub
   - Create an employment activity (self-attested), complete, verify progress updates
   - Connect a payroll account (validated employment), complete through payment details, verify it appears
   - Create an education activity (fully self-attested), complete, verify progress
   - Open two tabs, create activities in each, verify no cross-tab issues
   - Verify the summary page only shows published activities
4. **Cleanup job**: Verify `DraftCleanupJob.perform_now` deletes old drafts and preserves recent ones
