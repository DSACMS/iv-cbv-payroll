require "rails_helper"

RSpec.describe NavigationTracking do
  let(:navigation_tracking_test_class) do
    Class.new do
      include Trackable
      include NavigationTracking

      attr_accessor :current_agency, :event_logger, :request, :params
      attr_writer :flow
    end
  end
  let(:instance) { navigation_tracking_test_class.new }
  let(:event_logger) { instance_double(GenericEventTracker, track: nil) }
  let(:current_agency) { instance_double(ClientAgencyConfig::ClientAgency, id: "test_agency") }
  let(:fake_request) { instance_double(ActionDispatch::Request) }
  let(:flow) { instance_double(ActivityFlow, id: 101, cbv_applicant_id: 202, invitation_id: 303) }
  let(:navigation_params) { { from_edit: "1", from_review: "1" } }

  before do
    instance.event_logger = event_logger
    instance.current_agency = current_agency
    instance.request = fake_request
    instance.flow = flow
    instance.params = navigation_params
  end

  describe "#track_event" do
    it "includes navigation context alongside standard and event attributes" do
      instance.track_event("SomeEvent", num_results: 3)

      expect(event_logger).to have_received(:track).with(
        "SomeEvent",
        fake_request,
        {
          client_agency_id: current_agency.id,
          cbv_flow_id: flow.id,
          cbv_applicant_id: flow.cbv_applicant_id,
          invitation_id: flow.invitation_id,
          from_edit: "1",
          from_review: "1",
          num_results: 3
        }
      )
    end

    context "when navigation parameters are absent" do
      let(:navigation_params) { {} }

      it "tracks nil navigation values" do
        instance.track_event("SomeEvent")

        expect(event_logger).to have_received(:track).with(
          "SomeEvent", fake_request, hash_including(from_edit: nil, from_review: nil)
        )
      end
    end

    context "when navigation parameters are blank" do
      let(:navigation_params) { { from_edit: "", from_review: "" } }

      it "tracks nil navigation values" do
        instance.track_event("SomeEvent")

        expect(event_logger).to have_received(:track).with(
          "SomeEvent", fake_request, hash_including(from_edit: nil, from_review: nil)
        )
      end
    end
  end
end
