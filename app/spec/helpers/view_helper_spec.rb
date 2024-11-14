require 'rails_helper'

RSpec.describe ViewHelper, type: :helper do
  describe '#translate_pinwheel_value' do
    # Store the original locale before all tests
    let(:original_locale) { I18n.default_locale }

    # Reset locale after each test
    after { I18n.locale = original_locale }

    context 'when locale is :es' do
      before { I18n.locale = :es }

      it 'returns the translated value if translation exists' do
        I18n.backend.store_translations(:es, {
          pinwheel: {
            namespace: {
              existing_value: 'Translated Value'
            }
          }
        })

        result = helper.translate_pinwheel_value('namespace', 'existing_value')
        expect(result).to eq('Translated Value')
      end

      it 'raises an error in development or test if translation is missing' do
        # Use a key that doesn't exist
        expect {
          helper.translate_pinwheel_value('namespace', 'missing_value')
        }.to raise_error('Missing Pinwheel translation for namespace.missing_value')
      end

      it 'logs a warning and returns the original value in production if translation is missing' do
        # Simulate production environment
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:test?).and_return(false)

        # Expect a warning to be logged
        expect(Rails.logger).to receive(:warn).with('Unknown Pinwheel value for namespace: missing_value')

        result = helper.translate_pinwheel_value('namespace', 'missing_value')
        expect(result).to eq('missing_value')
      end
    end

    context 'when locale is not :es' do
      before { I18n.locale = :en }

      it 'returns the original value regardless of translations' do
        result = helper.translate_pinwheel_value('namespace', 'any_value')
        expect(result).to eq('any_value')
      end
    end
  end
end
