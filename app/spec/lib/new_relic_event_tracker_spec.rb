require 'rails_helper'
require 'new_relic_event_tracker'

RSpec.describe NewRelicEventTracker do
  describe '.track' do
    let(:event_type) { 'TestEvent' }
    let(:attributes) { { key: 'value' } }

    before do
      allow(NewRelicEventTracker).to receive(:track).and_call_original
    end

    it 'calls NewRelic::Agent.record_custom_event with correct parameters' do
      expect(NewRelic::Agent).to receive(:record_custom_event).with(event_type, attributes)
      described_class.track(event_type, attributes)
    end

    context 'when an error occurs' do
      before do
        allow(NewRelic::Agent).to receive(:record_custom_event).and_raise(StandardError.new('Test error'))
      end

      it 'logs an error message' do
        expect(Rails.logger).to receive(:error).with("Failed to send New Relic event: Test error")
        described_class.track(event_type, attributes)
      end
    end
  end
end
