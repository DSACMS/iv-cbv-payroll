# Shared Mixpanel event-tracking helper for both the CBV (Income) and
# Activities (CE) flows. See the taxonomy design doc for the full naming
# convention and standard-parameter list:
# docs/superpowers/specs/2026-08-06-ce-mixpanel-taxonomy-confluence-page.txt
#
# Usage from a controller:
#
#   track_event(TrackEvent::HubViewed, some_extra_param: "value")
#
# `client_agency_id`, `cbv_flow_id`, `cbv_applicant_id`, and `invitation_id`
# are attached automatically from `current_agency`/`@flow`. `time`,
# `flow_type`, `device_id`, and `locale` are attached automatically further
# downstream in GenericEventTracker#prep_request_attributes. Add new event
# names to TrackEvent before referencing them here.
#
# From frontend/Stimulus code, use `trackUserAction()`
# (app/javascript/utilities/api.js) instead, which round-trips through this
# same pipeline via Api::UserEventsController.
module Trackable
  extend ActiveSupport::Concern

  def track_event(event_name, extra_attributes = {})
    event_logger.track(event_name, request, standard_track_attributes.merge(extra_attributes))
  end

  private

  def standard_track_attributes
    # Snapshot @flow before calling current_agency: ApplicationController#current_agency
    # reassigns `@flow = @cbv_flow` as a legacy compatibility shim, which clobbers @flow
    # back to nil in any controller (like Api::UserEventsController) that sets @flow
    # directly without also setting the legacy @cbv_flow alias. This snapshot (and the
    # shim itself, in ApplicationController#current_agency) can be deleted once every
    # controller is converted to use @flow exclusively and @cbv_flow is retired.
    flow = @flow
    attrs = { client_agency_id: current_agency&.id }
    return attrs unless flow

    attrs.merge(
      cbv_flow_id: flow.id,
      cbv_applicant_id: flow.cbv_applicant_id,
      invitation_id: flow.invitation_id
    )
  end
end
