# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenericEventTracker do
  describe '#track' do
    around do |example|
      ClimateControl.modify ACTIVEJOB_ENABLED: 'true' do
        example.run
      end
    end

    it 'populates default attributes' do
      expect(EventTrackingJob).to receive(:perform_later).with("myEvent", anything, hash_including(
        time: an_instance_of(Integer),
        cbv_flow_id: "cbv_flow_id",
        locale: an_instance_of(String),
        user_agent: "user_agent",
        client_agency_id: "client_agency_id",
        ip: "ip"
      ))
      request_mock = instance_double(ActionDispatch::Request, params: { "client_agency_id" => "client_agency_id" }, session: { cbv_flow_id: "cbv_flow_id" }, remote_ip: "ip", headers: { "User-Agent" => "user_agent" })
      described_class.new.track("myEvent", request_mock, {})
    end

    context 'raises an error' do
      let(:request_mock) { instance_double(ActionDispatch::Request, params: { "client_agency_id" => "client_agency_id" }, session: { cbv_flow_id: "cbv_flow_id" }, remote_ip: "ip", headers: { "User-Agent" => "user_agent" }) }

      before do
        @event_type = "myEvent"
        allow(EventTrackingJob).to receive(:perform_later).and_raise(RuntimeError)
        allow(Rails.logger).to receive(:error)
        allow(Rails.env).to receive(:production?).and_return(false)
      end

      it 'logs to error with that event and reraises an error in non prod environments' do
        expect { described_class.new.track(@event_type, request_mock, {}) }
          .to raise_error(RuntimeError)
        expect(Rails.logger).to have_received(:error)
          .with(/Unable to track event \(#{@event_type}\): RuntimeError, line: /)
          .with(/line: /)
          .with(/.rb:/)
      end

      it 'logs an error but does not raise in prod' do
        allow(Rails.env).to receive(:production?).and_return(true)

        request_mock = instance_double(ActionDispatch::Request, params: { "client_agency_id" => "client_agency_id" }, session: { cbv_flow_id: "cbv_flow_id" }, remote_ip: "ip", headers: { "User-Agent" => "user_agent" })
        expect { described_class.new.track(@event_type, request_mock, {}) }
          .not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Unable to track event \(#{@event_type}\): RuntimeError/)
      end
    end
  end
end
