require 'rails_helper'
require 'yaml'

RSpec.describe TranslationService do
  let(:csv_path) { Rails.root.join('spec', 'support', 'fixtures', 'I18n', 'snap_income_pilot_translations.csv') }
  let(:output_path) { Rails.root.join('tmp', 'test.yml') }

  after(:each) do
    # File.delete(output_path) if File.exist?(output_path)
  end

  describe '#generate' do
    let(:service) { TranslationService.new }

    context 'with Spanish translations' do
      it 'generates a YAML file with Spanish translations and skips rows based on condition' do
        processor = lambda do |row|
          row[:added_to_confluence]&.strip == 'No need for translation' || row[:spanish].to_s.strip.empty?
        end

        result = service.generate(
          csv_path.to_s,
          output_path.to_s,
          target_locale: 'es',
          middleware: [ processor ]
        )

        expect(File.exist?(output_path)).to be true
        yaml_content = YAML.load_file(output_path)
        expect(yaml_content).to have_key('es')
        expect(yaml_content).not_to have_key('en')
        expect(yaml_content['es']).not_to be_empty
        expect(yaml_content['es'].keys).to include('applicant_mailer', 'caseworker', 'cbv', 'pages', 'shared', 'us_form_with', 'users')
      end
    end

    it 'applies processors to modify rows' do
      processor = lambda do |row|
        row[:spanish] = row[:spanish]&.strip
        row
      end

      service.generate(
        csv_path.to_s,
        output_path.to_s,
        target_locale: 'es',
        middleware: [ processor ]
      )
      expect(service.rows).not_to eq(0)
    end
  end
end
