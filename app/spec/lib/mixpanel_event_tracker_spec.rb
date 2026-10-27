require 'rails_helper'

RSpec.describe MixpanelEventTracker do
  describe '.track' do
    let(:event_type) { 'TestEvent' }
    let(:request) { nil }
    let(:attributes) { { key: 'value' } }
    let(:tracker) { described_class.for_request(nil) }

    before do
      # Since we're stubbing this in spec_helper, make our tests in this file call original as well
      allow_any_instance_of(described_class).to receive(:track).and_call_original
    end

    it 'calls Mixpanel::Tracker.track with correct parameters' do
      expect_any_instance_of(Mixpanel::Tracker).to receive(:track)
      tracker.track(event_type, request, attributes)
    end

    context 'when attributes have symbol keys that overlap with Mixpanel default properties' do
      let(:attributes) { { time: 1_700_000_000, key: 'value' } }
      let(:sent_messages) { [] }

      before do
        allow_any_instance_of(Mixpanel::Consumer).to receive(:send!) do |_consumer, type, message|
          sent_messages << [ type, message ]
        end
      end

      it 'sends the event with our time value instead of raising a duplicate key error' do
        expect { tracker.track(event_type, request, attributes) }.not_to raise_error

        _type, message = sent_messages.last
        properties = JSON.parse(message)["data"]["properties"]
        expect(properties).to include("time" => 1_700_000_000, "key" => "value")
      end
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
