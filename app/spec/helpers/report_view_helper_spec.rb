require 'rails_helper'

RSpec.describe ReportViewHelper, type: :helper do
  describe '#format_hours' do
    it "rounds to the nearest tenth" do
      expect(helper.format_hours(57.3611)).to eq(57.4)
      expect(helper.format_hours(57.3411)).to eq(57.3)
    end

    it "ignores non numbers" do
      expect(helper.format_hours("hours")).to eq("hours")
      expect(helper.format_hours("30h")).to eq("30h")
    end
  end

  describe '#translate_aggregator_value' do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context 'when locale is :es' do
      let(:locale) { :es }

      it 'returns the translated value if translation exists' do
        I18n.backend.store_translations(:es, {
          aggregator_strings: {
            namespace: {
              existing_value: 'Translated Value'
            }
          }
        })

        result = helper.translate_aggregator_value('namespace', 'existing_value')
        expect(result).to eq('Translated Value')
      end

      it 'raises an error in development or test if translation is missing' do
        # Use a key that doesn't exist
        expect {
          helper.translate_aggregator_value('namespace', 'missing_value')
        }.to raise_error('Missing aggregator translation for namespace.missing_value')
      end

      it 'logs a warning and returns the original value in production if translation is missing' do
        # Simulate production environment
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:test?).and_return(false)

        # Expect a warning to be logged
        expect(Rails.logger).to receive(:warn).with('Unknown aggregator value for namespace: missing_value')

        result = helper.translate_aggregator_value('namespace', 'missing_value')
        expect(result).to eq('missing_value')
      end
    end

    context 'when locale is not :es' do
      let(:locale) { :en }

      before do
        I18n.backend.store_translations(:en, {
          aggregator_strings: {
            namespace: {
              some_value: 'Translated Value'
            }
          }
        })
      end

      it 'returns the English value' do
        result = helper.translate_aggregator_value('namespace', 'some_value')
        expect(result).to eq('Translated Value')
      end

      context 'when the value is nil' do
        it 'returns nil' do
          result = helper.translate_aggregator_value('namespace', nil)
          expect(result).to be_nil
        end
      end

      context 'when there is no English value given' do
        it 'returns the original value regardless of translations' do
          result = helper.translate_aggregator_value('namespace', 'any_value')
          expect(result).to eq('any_value')
        end
      end
    end
  end
end
