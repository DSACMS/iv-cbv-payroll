# Always confirm exit in activity creation flows

## Problem

In the activity creation flow, clicking the "Exit" button in the header only
shows the "are you sure?" confirmation modal when the current form is dirty
(i.e., the user has edited an input). On pages with no form, or on forms the
user hasn't touched, clicking Exit navigates away immediately, silently
discarding any draft activity the user has built up across earlier steps.

The edit flow — reached from the hub's Edit button — has different stakes: the
activity is already saved, and a clean form really means "no changes to lose."
The existing dirty-only behavior is correct there.

## Goal

- **Creation flow**: the confirmation modal appears every time the user clicks
  Exit, regardless of whether the current form is dirty.
- **Edit flow** (user arrived via the hub's Edit button): unchanged — the modal
  appears only when the form is dirty.

## How we distinguish the flows

The codebase already has a canonical signal for "user arrived from the hub's
Edit button": the `from_edit` query parameter. It is set by the hub's edit
link and threaded through every subsequent request in the flow. Its purpose
is documented at the top of each activity controller (e.g.,
`app/controllers/activities/education_controller.rb:3`).

- `params[:from_edit].present?` → edit flow
- `params[:from_edit].blank?` → creation flow

This covers every case:

| View reached via | `from_edit` | Behavior |
|---|---|---|
| `new.html.erb` (fresh activity) | absent | always confirm |
| `edit.html.erb` / `months/edit.html.erb` / `review.html.erb` from hub | present | dirty-only |
| Same views mid-creation (e.g., via review's edit link with `from_review=1`) | absent | always confirm |
| `verify.html.erb` / `show.html.erb` / `error.html.erb` / `payment_details/show.html.erb` / `document_uploads/new.html.erb` / `synchronization_failures/show.html.erb` / `employer_searches/show.html.erb` | absent | always confirm |

## Design

### Component

`ActivityFlowHeaderComponent` computes the flag internally — no new
constructor argument, no changes to the ~15 views that render it.

A `confirm_on_exit?` method on the component reads the request param via
`helpers.params`:

```ruby
# app/components/activity_flow_header_component.rb
def confirm_on_exit?
  helpers.params[:from_edit].blank?
end
```

The template (`activity_flow_header_component.html.erb`) exposes it as a
Stimulus data value on the root element:

```erb
<div class="activity-flow-header"
     data-controller="activity-flow-header"
     data-activity-flow-header-exit-url-value="<%= exit_url %>"
     data-activity-flow-header-confirm-on-exit-value="<%= confirm_on_exit? %>">
```

### Stimulus controller

`app/javascript/controllers/activity_flow_header_controller.js` gains a new
`confirmOnExit` boolean value, and `handleExit` gates on `confirmOnExit ||
isDirty`:

```js
static values = { exitUrl: String, confirmOnExit: Boolean }

handleExit(event) {
  event.preventDefault()
  if (this.confirmOnExitValue || this.isDirty) {
    this.element.querySelector("[data-open-modal]").click()
  } else {
    window.location.href = this.exitUrlValue
  }
}
```

The dirty-tracking code is untouched.

### Tests

Extend `spec/components/activity_flow_header_component_spec.rb`:

- When rendered with no `from_edit` param → the root element has
  `data-activity-flow-header-confirm-on-exit-value="true"`.
- When rendered with `from_edit=1` → the value is `"false"`.

No JS unit test; the controller change is a single `||`. I'll verify the
behavior in a browser against the creation flow (clean form → modal) and the
edit flow (clean form → direct navigation).

## Out of scope

- The modal's copy, layout, and close behavior.
- The dirty-tracking logic.
- Any change to how `from_edit` is threaded through controllers.
- Any view-level refactoring.
