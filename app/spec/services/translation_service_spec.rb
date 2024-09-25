require 'rails_helper'
require 'yaml'

RSpec.describe SpanishTranslationService do
  let(:csv_path) { Rails.root.join('spec', 'support', 'fixtures', 'I18n', 'snap_income_pilot_translations.csv') }
  let(:output_path) { Rails.root.join('tmp', 'test.yml') }

  after(:each) do
    File.delete(output_path) if File.exist?(output_path)
  end

  describe '#generate' do
    let(:service) { SpanishTranslationService.new }

    context 'with Spanish translations' do
      it 'generates a YAML file with Spanish translations and skips rows based on condition' do
        result = service.generate(
          csv_path.to_s,
          output_path.to_s
        )

        expect(File.exist?(output_path)).to be true
        yaml_content = YAML.load_file(output_path)

        # yaml and generated results should match
        expect(yaml_content).to eq(result)
        expect(yaml_content).to have_key('es')
        expect(yaml_content).not_to have_key('en')
        expect(yaml_content['es']).not_to be_empty
        expect(yaml_content['es'].keys).to include('applicant_mailer', 'caseworker', 'cbv', 'pages', 'shared', 'us_form_with', 'users')
      end
    end
  end
end
