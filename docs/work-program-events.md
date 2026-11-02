# Work Program Self Attested Flow Events

FFS-4638 instruments the Work Program flow using the FFS-4634 shared helper and
the naming pattern in the [Emmy CE Events taxonomy](https://confluenceent.cms.gov/pages/viewpage.action?pageId=1447694203).
The following rows are ready to add to that page; publication is pending.

As in the Employment and Education flows, `WorkProgramInfoViewed` marks entry
and `WorkProgramReviewSubmitted` marks completion of an activity. These events
also fire when editing existing activities; they are not unique session counters.
Completion fires after the activity is published, not when the entire CE report
is submitted.

| Page | Description | Event name | Notes |
| --- | --- | --- | --- |
| `job_training_controller.rb` | Views the new or edit information form | `WorkProgramInfoViewed` | Activity ID is null before creation |
| `job_training_controller.rb` | Successfully submits information | `WorkProgramInfoSubmitted` | Includes creation and editing |
| `job_training_controller.rb` | Information fails validation | `WorkProgramInfoValidationFailed` | Includes `error_fields` |
| `job_training/months_controller.rb` | Views a monthly hours form | `WorkProgramMonthViewed` | Includes `month_index` and `month` |
| `job_training/months_controller.rb` | Successfully submits monthly hours | `WorkProgramMonthSubmitted` | Includes `month_index` and `month` |
| `job_training/months_controller.rb` | Monthly hours fail validation | `WorkProgramMonthValidationFailed` | Includes month attributes and `error_fields` |
| `document_uploads_controller.rb` | Views the document upload page | `WorkProgramDocumentUploadViewed` | Scoped by `job_training_id` |
| `document_uploads_controller.rb` | Successfully submits the upload step | `WorkProgramDocumentUploadSubmitted` | Includes `document_count`; continuing without files counts as a submission |
| `document_uploads_controller.rb` | Upload submission fails validation | `WorkProgramDocumentUploadValidationFailed` | Includes `error_fields`; no successful submission event |
| `job_training_controller.rb` | Views the review page | `WorkProgramReviewViewed` | |
| `job_training_controller.rb` | Saves the review and publishes the activity | `WorkProgramReviewSubmitted` | Activity completion |
| `activity_flow_header_controller.js` | Clicks Exit | `WorkProgramExitClicked` | `modal_shown` distinguishes direct exit from confirmation |
| `activity_flow_header_controller.js` | Confirms exit | `WorkProgramExitModalConfirmed` | |
| `activity_flow_header_controller.js` | Cancels exit | `WorkProgramExitModalCancelled` | Both Go back and the close icon |
| `activity_flow_header_controller.js` | Clicks the header back arrow | `WorkProgramBackClicked` | |

## Parameters and delivery

Server events use `Trackable#track_event`. Navigation uses the existing header's
`trackUserAction` helper and the event API. Both use the shared event pipeline,
which supplies `cbv_flow_id`, `cbv_applicant_id`, `invitation_id`,
`client_agency_id`, `time`, `device_id`, `flow_type` (`ce`), `locale`, `ip`, and
`user_agent`, subject to the available session and request context.

Server events add `job_training_activity_id` and the existing `from_edit` and
`from_review` navigation attributes. Header events retain the existing helper's
parameters; they do not add the activity ID or server navigation attributes.
Month indexes are zero-based, and `month` uses the existing localized
`month_year` format. `document_count` counts attachments on the activity after
submission. `error_fields` contains field names only.

Events do not include entered names, contact details, comments, hours, document
contents, or filenames. A server validation rerender fires the failure event,
not an additional page-view event. Browser-native validation that prevents a
request does not fire a server submission event, consistent with the other flows.

## QA and acceptance

Automated coverage verifies controller events, shared parameters, header
navigation for all three instrumented activity types, and the tokenized Work
Program monthly validation path. The browser test verifies a failed submission,
successful correction, and the subsequent upload view.

The following acceptance steps remain:

- Publish these rows on the Emmy CE Events Confluence page.
- In Mixpanel's live/debug view, follow a tokenized Work Program flow through
  information, each reporting month, upload, and review. Check event names,
  standard identifiers, month attributes, and completion after publication.
- Check editing from the hub and review, server validation failures, uploads
  with and without files, and back/exit navigation. Exercise both cancel controls
  and confirm exit; check `modal_shown` for confirmation and direct exits where
  the flow permits them.
- Confirm that validation failures do not emit successful submissions or extra
  view events, and that payloads contain no submitted personal information.
- Record design and product acceptance.
