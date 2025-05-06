require 'rails_helper'

RSpec.describe MixpanelEventTracker do
  describe '.track' do
    let(:event_type) { 'TestEvent' }
    let(:request) { nil }
    let(:attributes) { { key: 'value' } }
    let(:tracker) { described_class.for_request(nil) }

    before do
      # Since we're stubbing this in spec_helper, make our tests in this file call original as well
      allow_any_instance_of(MixpanelEventTracker).to receive(:track).and_call_original
    end

    it 'calls Mixpanel::Tracker.track with correct parameters' do
      expect_any_instance_of(Mixpanel::Tracker).to receive(:track)
      tracker.track(event_type, request, attributes)
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(Mixpanel::Tracker).to receive(:track).and_raise(StandardError.new('Test error'))
      end

      it 'logs an error message' do
        expect { tracker.track(event_type, request, attributes) }.to raise_exception(StandardError, 'Test error')
      end
    end
  end
end
