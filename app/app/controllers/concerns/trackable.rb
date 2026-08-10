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
    # directly without also setting the legacy @cbv_flow alias.
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
