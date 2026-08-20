# Reusable assertion for controller specs verifying a Trackable#track_event
# call, so per-flow tickets can add coverage for a new event without writing
# a new EventTrackingJob expectation from scratch each time. The including
# spec must define:
#   - `tracked_flow` — the CbvFlow/ActivityFlow the request is scoped to
#   - `perform_tracked_action` — the request that should fire the event (e.g. `get :index`)
#
# `extra_attributes` is a zero-arg block evaluated inside the example (so it can use
# matchers like `kind_of(Integer)`, which only work in example scope, not group scope).
#
# Usage:
#   it_behaves_like "tracks an event", TrackEvent::HubViewed
#   it_behaves_like "tracks an event", TrackEvent::SomeEvent, extra_attributes: -> { { foo: "bar" } }
RSpec.shared_examples "tracks an event" do |event_name, extra_attributes: -> { {} }|
  it "tracks #{event_name}" do
    expect(EventTrackingJob).to receive(:perform_later).with(
      event_name,
      anything,
      hash_including(
        cbv_flow_id: tracked_flow.id,
        cbv_applicant_id: tracked_flow.cbv_applicant_id,
        invitation_id: tracked_flow.invitation_id,
        client_agency_id: tracked_flow.cbv_applicant.client_agency_id,
        **instance_exec(&extra_attributes)
      )
    )

    perform_tracked_action
  end
end
