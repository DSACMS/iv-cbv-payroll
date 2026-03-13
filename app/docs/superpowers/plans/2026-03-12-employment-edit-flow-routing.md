# Employment Edit Flow Routing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the hub's "Edit" link for self-attested employment to go to the review page (instead of the edit-info page), so that `from_review` naturally signals "editing a specific piece" and `from_edit` only signals "entered from the hub."

**Architecture:** One routing change (hub helper → review page), one controller change (stop hardcoding `from_edit: 1`, thread the param instead), and test updates. Views and the `MonthlyHoursInput` concern are already correct.

**Tech Stack:** Ruby on Rails, ERB views, RSpec

---

## Context

### Current param semantics (broken)
- `from_edit` — set by the `update` action (hardcoded `1`), intended to mean "editing from hub" but actually means "user submitted the edit form." Gets set during creation flow if user navigates back.
- `from_review` — set by "Edit" links on the review page, means "send me back to review when done." Works correctly.

### New param semantics (after this change)
- `from_edit` — set ONLY by the hub's edit link. Means "user entered this flow from the hub's Edit button." Controls review page submit button label ("Save changes" vs "Save and add to my report").
- `from_review` — unchanged. Set by "Edit" links on the review page. Means "send me back to review when done."

### Key flow changes
- **Hub "Edit" → review page** (was: edit-info page). The review page's `ensure_review_ready` guard handles incomplete activities.
- **`update` action keeps the `from_review` conditional** — when user edits employer info from review, they should go straight back to review (not through months). The only change: replace hardcoded `from_edit: 1` with `from_edit: params[:from_edit].presence` so it threads the param instead of always setting it.

### What NOT to change
- `MonthlyHoursInput` concern — already correct
- `months_controller.rb` `set_back_url` — already correct (uses `from_review` and `from_edit` from params)
- `months/edit.html.erb` — already correct (header and form URL use params)
- `review.html.erb` edit links — already pass `from_review: 1` and `from_edit: params[:from_edit].presence`

## Files to Modify

| File | Change |
|------|--------|
| `app/app/helpers/activities_helper.rb` | Hub edit link → review path with `from_edit: 1` |
| `app/app/controllers/activities/employment_controller.rb` | Thread `from_edit` param instead of hardcoding `1` |
| `app/spec/controllers/activities/employment_controller_spec.rb` | Update redirect expectations, add `from_edit` threading tests |
| `app/spec/e2e/activity_hub_employment_self_attestation_spec.rb` | Update review button label expectation |

---

## Task 1: Change hub edit link to point to review page

**Files:**
- Modify: `app/app/helpers/activities_helper.rb:51`

- [ ] **Step 1: Update the edit path**

Change line 51 from:

```ruby
edit_path: edit_activities_flow_income_employment_path(id: activity.id)
```

to:

```ruby
edit_path: review_activities_flow_income_employment_path(id: activity.id, from_edit: 1)
```

This is the only place `from_edit` gets set. It means "user entered from the hub."

- [ ] **Step 2: Verify**

Run: `cd app && bin/rspec spec/controllers/activities/activities_controller_spec.rb -v`
Expected: All tests pass (hub tests don't assert on the specific edit path value).

---

## Task 2: Update employment controller update action

**Files:**
- Modify: `app/app/controllers/activities/employment_controller.rb`

The `from_review` branch in `update` is correct and stays — when the user edits employer info from the review page, they should go straight back to review. The only change: replace hardcoded `from_edit: 1` with `from_edit: params[:from_edit].presence` in both branches so the param is threaded instead of always set.

- [ ] **Step 1: Update the update action**

Replace the `update` method with:

```ruby
def update
  if @employment_activity.update(employment_activity_params)
    if params[:from_review].present?
      redirect_to review_activities_flow_income_employment_path(
        id: @employment_activity,
        from_edit: params[:from_edit].presence
      )
    else
      redirect_to edit_activities_flow_income_employment_month_path(
        employment_id: @employment_activity,
        id: 0,
        from_edit: params[:from_edit].presence
      )
    end
  else
    render :edit, status: :unprocessable_content
  end
end
```

Key difference from current code: `from_edit: params[:from_edit].presence` instead of `from_edit: 1` in the non-review branch. The review branch is unchanged.

Note: `set_back_url` already threads `from_edit` correctly — no change needed there.

- [ ] **Step 2: Verify**

Run: `cd app && bin/rspec spec/controllers/activities/employment_controller_spec.rb -v`
Expected: The "updates the activity and redirects to the first month page" test will fail (expects `from_edit: 1` but now gets no `from_edit`). We'll fix this in Task 3.

---

## Task 3: Update tests

**Files:**
- Modify: `app/spec/controllers/activities/employment_controller_spec.rb`
- Modify: `app/spec/e2e/activity_hub_employment_self_attestation_spec.rb`

- [ ] **Step 1: Update controller spec — update redirect (default case)**

The test at line 97-102 expects redirect to month 0 with `from_edit: 1`. Now it should redirect to month 0 WITHOUT `from_edit` (since there's no `from_edit` in the request params):

```ruby
it "updates the activity and redirects to the first month page" do
  patch :update, params: { id: employment_activity.id, employment_activity: { employer_name: "Updated Corp" } }

  expect(employment_activity.reload.employer_name).to eq("Updated Corp")
  expect(response).to redirect_to(edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0))
end
```

- [ ] **Step 2: Add controller spec — from_edit threading**

Add a test that verifies `from_edit` is threaded through when present:

```ruby
it "threads from_edit through to the redirect" do
  patch :update, params: { id: employment_activity.id, from_edit: 1, employment_activity: { employer_name: "Updated Corp" } }

  expect(response).to redirect_to(edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0, from_edit: 1))
end

it "threads from_edit through the from_review redirect" do
  patch :update, params: { id: employment_activity.id, from_review: 1, from_edit: 1, employment_activity: { employer_name: "Updated Corp" } }

  expect(response).to redirect_to(review_activities_flow_income_employment_path(id: employment_activity, from_edit: 1))
end
```

- [ ] **Step 3: Update e2e test — review page button label**

The e2e test at line 103 expects `I18n.t("activities.hub.save")` ("Save changes") on the review page after editing employer info during a creation flow. Since the creation flow has no `from_edit`, the button should say "Save and add to my report":

Change line 101-103 from:

```ruby
# Review page (edit flow — button should say "Save changes")
verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
expect(page).to have_button I18n.t("activities.hub.save")
```

to:

```ruby
# Review page (creation flow — button should say "Save and add to my report")
verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
expect(page).to have_button I18n.t("activities.employment.review.save")
```

- [ ] **Step 4: Verify all employment tests pass**

Run: `cd app && bin/rspec spec/controllers/activities/employment_controller_spec.rb spec/controllers/activities/employment/months_controller_spec.rb -v`
Expected: All tests pass.

Note: The existing e2e test covers the creation flow and review-page editing. The hub-edit happy path (hub → review with `from_edit=1` → edit something → save → hub) is not covered by an existing e2e scenario — this is intentionally deferred as it requires a more complex e2e setup with a pre-existing completed activity.

---

## Task 4: Run full test suite and lint

- [ ] **Step 1: Run all activity tests**

```bash
cd app && bin/rspec spec/controllers/activities/ -v
```

- [ ] **Step 2: Run lint**

```bash
cd app && bundle exec rubocop -a app/controllers/activities/employment_controller.rb app/helpers/activities_helper.rb
```
