require 'rails_helper'
require 'new_relic_event_tracker'

RSpec.describe NewRelicEventTracker do
  describe '.track' do
    let(:event_type) { 'TestEvent' }
    let(:request) { nil }
    let(:attributes) { { key: 'value' } }
    let(:tracker) { described_class.for_request(nil) }

    before do
      # Since we're stubbing this in spec_helper, make our tests in this file call original as well
      allow_any_instance_of(NewRelicEventTracker).to receive(:track).and_call_original
    end

    it 'calls NewRelic::Agent.record_custom_event with correct parameters' do
      expect(NewRelic::Agent).to receive(:record_custom_event)
      tracker.track(event_type, request, attributes)
    end

    context 'when an error occurs' do
      before do
        allow(NewRelic::Agent).to receive(:record_custom_event).and_raise(StandardError.new('Test error'))
      end

      it 'logs an error message' do
        expect { tracker.track(event_type, request, attributes) }.to raise_exception(StandardError, 'Test error')
      end
    end
  end
end
