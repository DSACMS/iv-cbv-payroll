# Draft Activity Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace session-based activity exclusion with a `draft` boolean on the model so incomplete activities are hidden from the hub and progress calculator without viral session threading.

**Architecture:** Add `draft` column (default `false`) to 5 tables. Activity flow create actions set `draft: true`. Completion actions (`save_review` / payment details `update`) call `publish!` to set `draft: false`. All display/progress queries use a `.published` scope. A recurring job cleans up stale drafts. All session-tracking machinery in `BaseController` is removed.

**Tech Stack:** Ruby on Rails 8.1, PostgreSQL, Solid Queue, RSpec

**Spec:** `docs/superpowers/specs/2026-04-09-draft-activity-flag-design.md`

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `app/db/migrate/YYYYMMDDHHMMSS_add_draft_to_activities_and_payroll_accounts.rb` | Migration |
| Modify | `app/app/models/activity.rb` | Add `published` scope and `publish!` |
| Modify | `app/app/models/payroll_account.rb` | Add `published` scope and `publish!` |
| Modify | `app/app/controllers/activities/base_controller.rb` | Remove session machinery, simplify `progress_calculator` and `after_activity_path` |
| Modify | `app/app/controllers/activities/activities_controller.rb` | Use `.published` scope |
| Modify | `app/app/controllers/activities/volunteering_controller.rb` | Set `draft: true` on create, `publish!` on save_review |
| Modify | `app/app/controllers/activities/job_training_controller.rb` | Set `draft: true` on create, `publish!` on save_review |
| Modify | `app/app/controllers/activities/employment_controller.rb` | Set `draft: true` on create, `publish!` on save_review |
| Modify | `app/app/controllers/activities/education_controller.rb` | Set `draft: true` on create, `publish!` on save_review |
| Modify | `app/app/controllers/activities/income/synchronizations_controller.rb` | Set `draft: true` on payroll account |
| Modify | `app/app/controllers/activities/income/payment_details_controller.rb` | `publish!` on update |
| Modify | `app/app/controllers/activities/summary_controller.rb` | Use `.published` scope |
| Modify | `app/app/controllers/activities/submit_controller.rb` | Use `.published` scope |
| Modify | `app/app/services/activity_flow_progress_calculator.rb` | Use `.published`, remove `exclude:` machinery |
| Modify | `app/app/views/activities/activities/index.html.erb` | Replace `@any_visible_activities` |
| Create | `app/app/jobs/draft_cleanup_job.rb` | Recurring job to delete stale drafts |
| Modify | `app/config/recurring.yml` | Register cleanup job |
| Modify | `app/spec/controllers/activities/activities_controller_spec.rb` | Rewrite hiding specs to use `draft: true` |
| Modify | `app/spec/services/activity_flow_progress_calculator_spec.rb` | Remove `exclude:` specs |
| Create | `app/spec/jobs/draft_cleanup_job_spec.rb` | Test cleanup job |

---

### Task 1: Migration

**Files:**
- Create: `app/db/migrate/YYYYMMDDHHMMSS_add_draft_to_activities_and_payroll_accounts.rb`

- [ ] **Step 1: Generate migration**

Run from `app/`:

```bash
bin/rails generate migration AddDraftToActivitiesAndPayrollAccounts
```

- [ ] **Step 2: Write migration**

```ruby
class AddDraftToActivitiesAndPayrollAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :volunteering_activities, :draft, :boolean, default: false, null: false
    add_column :job_training_activities, :draft, :boolean, default: false, null: false
    add_column :employment_activities, :draft, :boolean, default: false, null: false
    add_column :education_activities, :draft, :boolean, default: false, null: false
    add_column :payroll_accounts, :draft, :boolean, default: false, null: false
  end
end
```

- [ ] **Step 3: Run migration**

```bash
cd app && bin/rails db:migrate && RAILS_ENV=test bin/rails db:schema:load
```

Expected: Migration succeeds. `db/schema.rb` shows `draft` column on all 5 tables.

- [ ] **Step 4: Verify schema**

Check that `db/schema.rb` contains `t.boolean "draft", default: false, null: false` for each of the 5 tables.

---

### Task 2: Model — Activity base class

**Files:**
- Modify: `app/app/models/activity.rb`

- [ ] **Step 1: Write test for `published` scope and `publish!`**

Add to `app/spec/models/activity_spec.rb` (create if it doesn't exist — use VolunteeringActivity as the concrete class since Activity is abstract):

```ruby
require "rails_helper"

RSpec.describe Activity do
  # Activity is abstract; test via VolunteeringActivity
  let(:flow) { create(:activity_flow) }

  describe ".published" do
    it "returns only non-draft records" do
      published = create(:volunteering_activity, activity_flow: flow, draft: false)
      _draft = create(:volunteering_activity, activity_flow: flow, draft: true)

      expect(flow.volunteering_activities.published).to contain_exactly(published)
    end
  end

  describe "#publish!" do
    it "sets draft to false" do
      activity = create(:volunteering_activity, activity_flow: flow, draft: true)

      activity.publish!

      expect(activity.reload.draft).to be(false)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && bin/rspec spec/models/activity_spec.rb
```

Expected: FAIL — `NoMethodError: undefined method 'published'`

- [ ] **Step 3: Implement scope and method**

In `app/app/models/activity.rb`, add after `enum :data_source`:

```ruby
  scope :published, -> { where(draft: false) }

  def publish!
    update!(draft: false)
  end
```

The full file should read:

```ruby
class Activity < ApplicationRecord
  self.abstract_class = true

  belongs_to :activity_flow

  enum :data_source, { self_attested: "self_attested", validated: "validated" }, default: :self_attested

  scope :published, -> { where(draft: false) }

  def publish!
    update!(draft: false)
  end

  validate :date_within_reporting_window

  def date=(value)
    return unless has_attribute?(:date)

    self[:date] = DateFormatter.parse(value)
  end

  private

  def date_within_reporting_window
    return unless has_attribute?(:date)
    return if date.blank? || activity_flow.blank?

    unless activity_flow.reporting_window_range.cover?(date)
      errors.add(:date, :outside_reporting_window,
        range: activity_flow.reporting_window_display)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd app && bin/rspec spec/models/activity_spec.rb
```

Expected: PASS

---

### Task 3: Model — PayrollAccount

**Files:**
- Modify: `app/app/models/payroll_account.rb`

- [ ] **Step 1: Write test**

Add to `app/spec/models/payroll_account_spec.rb` (append to existing file or create):

```ruby
require "rails_helper"

RSpec.describe PayrollAccount do
  let(:flow) { create(:activity_flow) }

  describe ".published" do
    it "returns only non-draft records" do
      published = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: false)
      _draft = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true)

      expect(flow.payroll_accounts.published).to contain_exactly(published)
    end
  end

  describe "#publish!" do
    it "sets draft to false" do
      account = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true)

      account.publish!

      expect(account.reload.draft).to be(false)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && bin/rspec spec/models/payroll_account_spec.rb
```

Expected: FAIL — `NoMethodError: undefined method 'published'`

- [ ] **Step 3: Implement scope and method**

In `app/app/models/payroll_account.rb`, add after `enum :synchronization_status` block (after line 24):

```ruby
  scope :published, -> { where(draft: false) }

  def publish!
    update!(draft: false)
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd app && bin/rspec spec/models/payroll_account_spec.rb
```

Expected: PASS

---

### Task 4: Progress calculator — remove `exclude:` machinery

**Files:**
- Modify: `app/app/services/activity_flow_progress_calculator.rb`
- Modify: `app/spec/services/activity_flow_progress_calculator_spec.rb`

- [ ] **Step 1: Update the calculator**

Replace the constructor and remove exclusion methods. The new constructor (lines 10-16):

```ruby
  def initialize(activity_flow)
    @activity_flow = activity_flow
    @volunteering_activities = activity_flow.volunteering_activities.published
    @job_training_activities = activity_flow.job_training_activities.published
    @education_activities = activity_flow.education_activities.published
    @employment_activities = activity_flow.employment_activities.published
  end
```

Replace the `validated_account_ids` method (currently lines 166-171) with:

```ruby
  def validated_account_ids
    @validated_account_ids ||= @activity_flow.payroll_accounts.published
      .select(&:validated?)
      .map(&:aggregator_account_id)
      .compact
  end
```

Replace the `monthly_summaries` method (currently lines 172-175) with:

```ruby
  def monthly_summaries
    @monthly_summaries ||= @activity_flow.monthly_summaries_by_account_with_fallback
  end
```

Delete entirely:
- `excluded_payroll_account_ids` method (lines 176-179)
- `maybe_exclude` method (lines 181-184)

- [ ] **Step 2: Update calculator specs**

In `app/spec/services/activity_flow_progress_calculator_spec.rb`, remove any specs that test the `exclude:` parameter. These tests from the current branch should be deleted. The remaining specs that test `overall_result`, `monthly_results`, etc. should continue to work since factories create activities with `draft: false` by default.

- [ ] **Step 3: Run all calculator specs**

```bash
cd app && bin/rspec spec/services/activity_flow_progress_calculator_spec.rb
```

Expected: PASS

---

### Task 5: BaseController — remove session machinery, simplify helpers

**Files:**
- Modify: `app/app/controllers/activities/base_controller.rb`

- [ ] **Step 1: Remove the `recover_mismatched_flow` before_action**

Change line 2 from:

```ruby
  before_action :redirect_on_prod, :set_flow, :recover_mismatched_flow
```

to:

```ruby
  before_action :redirect_on_prod, :set_flow
```

- [ ] **Step 2: Delete session-tracking methods and constants**

Delete these entirely from the `private` section:
- `ACTIVITY_PARAMS` constant (lines 27-31)
- `recover_mismatched_flow` method (lines 36-57)
- `creating_records` method (lines 74-75)
- `creating_activity` method (lines 77-80)
- `creating_payroll_account` method (lines 82-85)
- `track_creating_activity` method (lines 87-88)
- `clear_creating_activity` method (lines 90-91)
- `track_creating_payroll_account` method (lines 93-94)
- `clear_creating_payroll_account` method (lines 96-97)
- `destroy_tracked_creating_activity` method (lines 99-102)
- `destroy_tracked_creating_payroll_account` method (lines 104-106)

- [ ] **Step 3: Simplify `after_activity_path`**

Replace the current `after_activity_path` (line 64-66):

```ruby
  def after_activity_path
    progress_result = ActivityFlowProgressCalculator.new(@flow).overall_result
    progress_result.meets_routing_requirements ? activities_flow_summary_path : activities_flow_root_path
  end
```

with:

```ruby
  def after_activity_path
    progress_result = progress_calculator.overall_result
    progress_result.meets_routing_requirements ? activities_flow_summary_path : activities_flow_root_path
  end
```

- [ ] **Step 4: Simplify `progress_calculator`**

Replace the current `progress_calculator` (lines 68-72):

```ruby
  def progress_calculator
    return nil unless @flow

    @_progress_calculator ||= ActivityFlowProgressCalculator.new(@flow, exclude: creating_records)
  end
```

with:

```ruby
  def progress_calculator
    return nil unless @flow

    @_progress_calculator ||= ActivityFlowProgressCalculator.new(@flow)
  end
```

- [ ] **Step 5: Verify the file looks clean**

The final `base_controller.rb` should contain only:
- `before_action :redirect_on_prod, :set_flow`
- `helper_method :current_identity, :progress_calculator`
- `current_identity`, `current_identity!`
- `redirect_on_prod`
- `after_activity_path` (simplified)
- `progress_calculator` (simplified)
- `flow_param`, `entry_path`, `invitation_class`, `invalid_token_message`, `track_invitation_clicked_event`

---

### Task 6: Activity controllers — set `draft: true` on create, `publish!` on save_review

**Files:**
- Modify: `app/app/controllers/activities/volunteering_controller.rb`
- Modify: `app/app/controllers/activities/job_training_controller.rb`
- Modify: `app/app/controllers/activities/employment_controller.rb`
- Modify: `app/app/controllers/activities/education_controller.rb`

- [ ] **Step 1: VolunteeringController**

In `create` (line 18), replace:

```ruby
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      track_creating_activity(@volunteering_activity)
```

with:

```ruby
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params.merge(draft: true))
    if @volunteering_activity.save
```

In `save_review` (line 37-38), replace:

```ruby
    @volunteering_activity.update(review_params)
    clear_creating_activity
    redirect_to after_activity_path
```

with:

```ruby
    @volunteering_activity.update(review_params)
    @volunteering_activity.publish!
    redirect_to after_activity_path
```

- [ ] **Step 2: JobTrainingController**

In `create` (line 18), replace:

```ruby
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      track_creating_activity(@job_training_activity)
```

with:

```ruby
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params.merge(draft: true))
    if @job_training_activity.save
```

In `save_review` (line 37-38), replace:

```ruby
    @job_training_activity.update(review_params)
    clear_creating_activity
    redirect_to after_activity_path
```

with:

```ruby
    @job_training_activity.update(review_params)
    @job_training_activity.publish!
    redirect_to after_activity_path
```

- [ ] **Step 3: EmploymentController**

In `create` (line 17), replace:

```ruby
    @employment_activity = @flow.employment_activities.new(employment_activity_params)
    if @employment_activity.save
      track_creating_activity(@employment_activity)
```

with:

```ruby
    @employment_activity = @flow.employment_activities.new(employment_activity_params.merge(draft: true))
    if @employment_activity.save
```

In `save_review` (line 37-38), replace:

```ruby
    @employment_activity.update(review_params)
    clear_creating_activity
    redirect_to after_activity_path
```

with:

```ruby
    @employment_activity.update(review_params)
    @employment_activity.publish!
    redirect_to after_activity_path
```

- [ ] **Step 4: EducationController**

In `create_fully_self_attested_activity` (line 101-103), replace:

```ruby
    @education_activity = @flow.education_activities.new(fully_self_attested_education_params)
    @education_activity.data_source = :fully_self_attested
    if @education_activity.save
      track_creating_activity(@education_activity)
```

with:

```ruby
    @education_activity = @flow.education_activities.new(fully_self_attested_education_params.merge(draft: true))
    @education_activity.data_source = :fully_self_attested
    if @education_activity.save
```

In `create_validated_activity` (line 105-106), replace:

```ruby
    @education_activity = @flow.education_activities.create
    track_creating_activity(@education_activity)
```

with:

```ruby
    @education_activity = @flow.education_activities.create(draft: true)
```

In `save_review` (line 65-66), replace:

```ruby
    @education_activity.update(review_params)
    clear_creating_activity
    redirect_to @education_activity.fully_self_attested? ? activities_flow_root_path : after_activity_path
```

with:

```ruby
    @education_activity.update(review_params)
    @education_activity.publish!
    redirect_to @education_activity.fully_self_attested? ? activities_flow_root_path : after_activity_path
```

- [ ] **Step 5: Run all activity controller specs**

```bash
cd app && bin/rspec spec/controllers/activities/volunteering_controller_spec.rb spec/controllers/activities/job_training_controller_spec.rb spec/controllers/activities/employment_controller_spec.rb spec/controllers/activities/education_controller_spec.rb
```

Expected: PASS (existing specs create activities via factories with `draft: false`, so they bypass the `create` action path)

---

### Task 7: PayrollAccount controllers — set `draft: true` on sync, `publish!` on payment details

**Files:**
- Modify: `app/app/controllers/activities/income/synchronizations_controller.rb`
- Modify: `app/app/controllers/activities/income/payment_details_controller.rb`

- [ ] **Step 1: SynchronizationsController**

Replace `track_payroll_account_creation` method (line 12):

```ruby
  def track_payroll_account_creation
    track_creating_payroll_account(params[:user][:account_id])
  end
```

with:

```ruby
  def track_payroll_account_creation
    payroll_account = @flow.payroll_accounts.find_by(aggregator_account_id: params[:user][:account_id])
    payroll_account&.update!(draft: true)
  end
```

- [ ] **Step 2: PaymentDetailsController**

In `update` (line 19), replace:

```ruby
    @payroll_account.update(payroll_account_params)
    clear_creating_payroll_account
```

with:

```ruby
    @payroll_account.update(payroll_account_params)
    @payroll_account.publish!
```

- [ ] **Step 3: Run income controller specs**

```bash
cd app && bin/rspec spec/controllers/activities/income/
```

Expected: PASS

---

### Task 8: Hub controller — use `.published` scope

**Files:**
- Modify: `app/app/controllers/activities/activities_controller.rb`
- Modify: `app/app/views/activities/activities/index.html.erb`
- Modify: `app/spec/controllers/activities/activities_controller_spec.rb`

- [ ] **Step 1: Rewrite the hub controller**

Replace the entire file `app/app/controllers/activities/activities_controller.rb` with:

```ruby
class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @community_service_activities = @flow.volunteering_activities.published.order(created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.published.order(created_at: :desc)
    @education_activities = @flow.education_activities.published.order(created_at: :desc)

    @employment_payroll_accounts = @flow.payroll_accounts.published.order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = @flow.employment_activities.published.order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end
end
```

- [ ] **Step 2: Update hub view**

In `app/app/views/activities/activities/index.html.erb`, replace line 14:

```erb
    <% if @any_visible_activities %>
```

with:

```erb
    <% if [@community_service_activities, @work_programs_activities, @education_activities, @employment_payroll_accounts, @employment_activities].any?(&:any?) %>
```

- [ ] **Step 3: Rewrite hub controller specs for draft behavior**

Replace the `describe "hiding incomplete activities on the hub"` block (lines 50-131) in `app/spec/controllers/activities/activities_controller_spec.rb` with:

```ruby
  describe "hiding draft activities on the hub" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
    end

    it "hides draft activities from the hub" do
      completed = create(:volunteering_activity, activity_flow: current_flow, draft: false)
      _draft = create(:volunteering_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(assigns(:community_service_activities)).to contain_exactly(completed)
    end

    it "shows all published activities" do
      activity = create(:volunteering_activity, activity_flow: current_flow, draft: false)

      get :index

      expect(assigns(:community_service_activities)).to contain_exactly(activity)
    end

    it "only hides draft activities of the matching type" do
      _draft_volunteering = create(:volunteering_activity, activity_flow: current_flow, draft: true)
      published_job_training = create(:job_training_activity, activity_flow: current_flow, draft: false)

      get :index

      expect(assigns(:community_service_activities)).to be_empty
      expect(assigns(:work_programs_activities)).to contain_exactly(published_job_training)
    end

    it "hides draft payroll accounts from the hub" do
      kept = create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, draft: false)
      _draft = create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, draft: true)

      get :index

      expect(assigns(:employment_payroll_accounts)).to contain_exactly(kept)
    end

    it "hides review and submit when the only activity is a draft" do
      create(:volunteering_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(response.body).not_to include(I18n.t("activities.hub.review_and_submit"))
    end

    it "shows review and submit when a published activity exists alongside a draft" do
      create(:volunteering_activity, activity_flow: current_flow, draft: false)
      create(:job_training_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end
  end
```

- [ ] **Step 4: Run hub controller specs**

```bash
cd app && bin/rspec spec/controllers/activities/activities_controller_spec.rb
```

Expected: PASS

---

### Task 9: Summary and submit controllers — add `.published`

**Files:**
- Modify: `app/app/controllers/activities/summary_controller.rb`
- Modify: `app/app/controllers/activities/submit_controller.rb`

- [ ] **Step 1: Summary controller**

In `load_summary_data` (line 30), replace:

```ruby
    @community_service_activities = @flow.volunteering_activities.order(created_at: :asc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :asc)
    @education_activities = @flow.education_activities.order(created_at: :asc)
    @employment_activities = @flow.payroll_accounts.select(&:sync_succeeded?)
```

with:

```ruby
    @community_service_activities = @flow.volunteering_activities.published.order(created_at: :asc)
    @work_programs_activities = @flow.job_training_activities.published.order(created_at: :asc)
    @education_activities = @flow.education_activities.published.order(created_at: :asc)
    @employment_activities = @flow.payroll_accounts.published.select(&:sync_succeeded?)
```

- [ ] **Step 2: Submit controller**

In `render_pdf` (line 10), replace:

```ruby
    @community_service_activities = @flow.volunteering_activities.order(date: :desc, created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.order(created_at: :desc)
```

with:

```ruby
    @community_service_activities = @flow.volunteering_activities.published.order(date: :desc, created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.published.order(created_at: :desc)
    @education_activities = @flow.education_activities.published.order(created_at: :desc)
```

- [ ] **Step 3: Run summary and submit specs**

```bash
cd app && bin/rspec spec/controllers/activities/summary_controller_spec.rb spec/controllers/activities/submit_controller_spec.rb
```

Expected: PASS

---

### Task 10: Draft cleanup job

**Files:**
- Create: `app/app/jobs/draft_cleanup_job.rb`
- Modify: `app/config/recurring.yml`
- Create: `app/spec/jobs/draft_cleanup_job_spec.rb`

- [ ] **Step 1: Write the test**

Create `app/spec/jobs/draft_cleanup_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DraftCleanupJob do
  let(:flow) { create(:activity_flow) }

  it "deletes draft activities older than 24 hours" do
    old_draft = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    recent_draft = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 1.hour.ago)
    published = create(:volunteering_activity, activity_flow: flow, draft: false, created_at: 25.hours.ago)

    described_class.perform_now

    expect(VolunteeringActivity.exists?(old_draft.id)).to be(false)
    expect(VolunteeringActivity.exists?(recent_draft.id)).to be(true)
    expect(VolunteeringActivity.exists?(published.id)).to be(true)
  end

  it "deletes draft payroll accounts older than 24 hours" do
    old_draft = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true, created_at: 25.hours.ago)
    published = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: false, created_at: 25.hours.ago)

    described_class.perform_now

    expect(PayrollAccount.exists?(old_draft.id)).to be(false)
    expect(PayrollAccount.exists?(published.id)).to be(true)
  end

  it "deletes drafts across all activity types" do
    old_volunteering = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_job_training = create(:job_training_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_employment = create(:employment_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_education = create(:education_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)

    described_class.perform_now

    expect(VolunteeringActivity.exists?(old_volunteering.id)).to be(false)
    expect(JobTrainingActivity.exists?(old_job_training.id)).to be(false)
    expect(EmploymentActivity.exists?(old_employment.id)).to be(false)
    expect(EducationActivity.exists?(old_education.id)).to be(false)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && bin/rspec spec/jobs/draft_cleanup_job_spec.rb
```

Expected: FAIL — `uninitialized constant DraftCleanupJob`

- [ ] **Step 3: Implement the job**

Create `app/app/jobs/draft_cleanup_job.rb`:

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

- [ ] **Step 4: Register in recurring.yml**

Add to `app/config/recurring.yml` under the `production:` key:

```yaml
  draft_cleanup:
    class: DraftCleanupJob
    schedule: every hour
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && bin/rspec spec/jobs/draft_cleanup_job_spec.rb
```

Expected: PASS

---

### Task 11: Full test suite verification

- [ ] **Step 1: Run full spec suite**

```bash
cd app && bin/rspec
```

Expected: All tests pass. If any tests fail due to referencing removed methods (`track_creating_activity`, `clear_creating_activity`, `creating_records`, `recover_mismatched_flow`, etc.), delete or update those tests — they test removed functionality.

- [ ] **Step 2: Run linter**

```bash
cd app && bundle exec rubocop -a
```

Expected: No offenses (or only pre-existing ones).

---

## Verification

After all tasks are complete:

1. **Run full test suite:** `cd app && bin/rspec` — all pass
2. **Run linter:** `cd app && bundle exec rubocop -a` — clean
3. **Manual smoke test (via `bin/dev`):**
   - Create a volunteering activity, abandon mid-flow, return to hub — should not appear
   - Create a volunteering activity, complete through review — should appear on hub and in progress
   - Create a self-attested employment activity, complete — should appear with progress
   - Connect a payroll account via Pinwheel, complete through payment details — should appear
   - Create a fully self-attested education activity, complete — should appear with progress
   - Open two tabs, create activities in each — no cross-tab issues
   - Navigate to summary page — only published activities shown
4. **Cleanup job:** `cd app && bin/rails runner "DraftCleanupJob.perform_now"` — verify it runs without error
