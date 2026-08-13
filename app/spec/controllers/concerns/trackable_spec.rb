require "rails_helper"

RSpec.describe Trackable do
  let(:trackable_test_class) do
    Class.new do
      include Trackable
      attr_accessor :current_agency, :event_logger, :request

      def flow=(flow)
        @flow = flow
      end
    end
  end
  let(:instance) { trackable_test_class.new }
  let(:event_logger) { instance_double(GenericEventTracker, track: nil) }
  let(:current_agency) { instance_double(ClientAgencyConfig::ClientAgency, id: "test_agency") }
  let(:fake_request) { instance_double(ActionDispatch::Request) }

  before do
    instance.event_logger = event_logger
    instance.current_agency = current_agency
    instance.request = fake_request
  end

  describe "#track_event" do
    context "when @flow is present" do
      let(:cbv_applicant) { create(:cbv_applicant) }
      let(:flow) { create(:cbv_flow, cbv_applicant: cbv_applicant) }

      before { instance.flow = flow }

      it "tracks the event with the flow's standard attributes merged with any extras" do
        instance.track_event("SomeEvent", num_results: 3)

        expect(event_logger).to have_received(:track).with(
          "SomeEvent",
          fake_request,
          {
            client_agency_id: "test_agency",
            cbv_flow_id: flow.id,
            cbv_applicant_id: flow.cbv_applicant_id,
            invitation_id: flow.invitation_id,
            num_results: 3
          }
        )
      end
    end

    context "when @flow is absent" do
      it "still tracks client_agency_id from current_agency, without flow-derived keys" do
        instance.track_event("SomeEvent")

        expect(event_logger).to have_received(:track).with(
          "SomeEvent",
          fake_request,
          { client_agency_id: "test_agency" }
        )
      end
    end

    context "when current_agency has the side effect of resetting @flow (as ApplicationController#current_agency does, via its `@flow = @cbv_flow` legacy compatibility shim)" do
      let(:trackable_test_class) do
        Class.new do
          include Trackable
          attr_accessor :event_logger, :request

          def flow=(flow)
            @flow = flow
          end

          # Mirrors ApplicationController#current_agency's `@flow = @cbv_flow`
          # side effect: a controller that only ever sets @flow (not the legacy
          # @cbv_flow alias) would have @flow clobbered back to nil by this call.
          def current_agency
            @flow = @cbv_flow
            Struct.new(:id).new("resolved_agency")
          end

          # No-op setter so the shared `before` block's `instance.current_agency =`
          # call doesn't blow up; the getter above is what actually matters here.
          def current_agency=(_agency); end
        end
      end

      let(:cbv_applicant) { create(:cbv_applicant) }
      let(:flow) { create(:cbv_flow, cbv_applicant: cbv_applicant) }

      before { instance.flow = flow }

      it "still includes flow-derived attributes, unaffected by current_agency's side effect" do
        instance.track_event("SomeEvent")

        expect(event_logger).to have_received(:track).with(
          "SomeEvent",
          fake_request,
          {
            client_agency_id: "resolved_agency",
            cbv_flow_id: flow.id,
            cbv_applicant_id: flow.cbv_applicant_id,
            invitation_id: flow.invitation_id
          }
        )
      end
    end
  end
end
