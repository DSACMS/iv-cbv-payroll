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
        timestamp: an_instance_of(Integer),
        cbv_flow_id: "cbv_flow_id",
        locale: an_instance_of(String),
        user_agent: "user_agent",
        client_agency_id: "client_agency_id",
        ip: "ip"
      ))
      request_mock = instance_double(ActionDispatch::Request, params: { "client_agency_id" => "client_agency_id" }, session: { cbv_flow_id: "cbv_flow_id" }, remote_ip: "ip", headers: { "User-Agent" => "user_agent" })
      described_class.new.track("myEvent", request_mock, {})
    end
  end
end
