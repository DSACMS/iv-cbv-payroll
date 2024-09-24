require 'rails_helper'
require 'yaml'

RSpec.describe TranslationService do
  let(:csv_path) { Rails.root.join('spec', 'support', 'fixtures', 'I18n', 'snap_income_pilot_translations.csv') }
  let(:output_path) { Rails.root.join('tmp', 'test.yml') }

  after(:each) do
    File.delete(output_path) if File.exist?(output_path)
  end

  describe '.generate' do
    let(:skip_condition) do
      lambda do |row|
        row[:added_to_confluence]&.strip == 'No need for translation'
      end
    end

    context 'with Spanish translations' do
      it 'generates a YAML file with Spanish translations and skips rows based on condition' do
        result = TranslationService.generate(
          csv_path.to_s,
          output_path.to_s,
          target_locale: 'es',
          skip_row_conditions: [
            TranslationService.skip_no_translation,
            skip_condition
          ]
        )

        expect(File.exist?(output_path)).to be true
        yaml_content = YAML.load_file(output_path)
        expect(yaml_content).to have_key('es')
        expect(yaml_content).not_to have_key('en')
        expect(yaml_content['es']).not_to be_empty
        expect(yaml_content['es'].keys).to include('applicant_mailer')
        expect(yaml_content['es'].keys).to include('caseworker')
        expect(yaml_content['es'].keys).to include('cbv')
        expect(yaml_content['es'].keys).to include('pages')
        expect(yaml_content['es'].keys).to include('shared')
        expect(yaml_content['es'].keys).to include('us_form_with')
        expect(yaml_content['es'].keys).to include('users')
      end
    end

    it 'applies row modifiers before processing' do
      # Modifier to trim whitespace from translation values
      row_modifier = lambda do |row|
        row[:spanish] = row[:spanish]&.strip
        row
      end

      result = TranslationService.generate(
        csv_path.to_s,
        output_path.to_s,
        target_locale: 'es',
        skip_row_conditions: [
          TranslationService.skip_no_translation,
          skip_condition
        ],
        row_modifiers: [ row_modifier ]
      )
      expect(result['es']).not_to be_empty
    end
  end
end
