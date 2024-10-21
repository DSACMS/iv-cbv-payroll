require 'rails_helper'
require 'yaml'

RSpec.describe TranslationService do
  let(:tmp_dir) { Rails.root.join('tmp', 'spec') }
  let(:csv_path) { tmp_dir.join('translations.csv') }
  let(:output_path) { tmp_dir.join('test_translations.yml') }
  let(:existing_translations_path) { tmp_dir.join('en.yml') }
  let(:current_locale_translations_path) { tmp_dir.join('es.yml') }
  let(:csv_contents) { @csv_contents }
  let(:logger_double) { instance_spy('Logger') }
  let(:log_messages) { [] }

  before do
    setup_test_environment
    mock_translation_service_methods
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:info) { |message| log_messages << message }
    allow(logger_double).to receive(:warn) { |message| log_messages << message }
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe '#generate' do
    context 'with default options' do
      let(:service) { TranslationService.new }

      it 'generates a YAML file with Spanish translations and logs combined collision details' do
        result = service.generate(csv_path.to_s, output_path.to_s)
        log_messages.each { |msg| puts msg }

        expect(File.exist?(output_path)).to be true
        yaml_content = YAML.load_file(output_path)

        expect(yaml_content).to eq(result)
        expect(yaml_content).to have_key('es')
        expect(yaml_content['es']['test']['key1']).to eq('Hola')
        expect(yaml_content['es']['test']['key2']).to eq('Old Mundo') # Not overwritten
        expect(yaml_content['es']['test']).not_to have_key('key3')
        expect(yaml_content['es']['test']).not_to have_key('key4')

        # Verify logging
        expect(logger_double).to have_received(:info).with(/Attempting to read CSV file:/)
        expect(logger_double).to have_received(:info).with(/Processing: Key:/).at_least(:once)
        expect(logger_double).to have_received(:info).with(/Total rows processed:/)
        expect(logger_double).to have_received(:info).with(/Successfully Imported:/)
        expect(logger_double).to have_received(:info).with(/Empty rows skipped:/)
        expect(logger_double).to have_received(:info).with(/Rows skipped by conditions:/)
        expect(logger_double).to have_received(:info).with(/Failed imports:/)
        expect(logger_double).to have_received(:info).with(/Collisions detected:/)
        expect(logger_double).to have_received(:info).with(/\nCollisions Details:/)
        expect(logger_double).to have_received(:info).with(/Key: .*?, Old Value: .*?, New Value: .*?/).at_least(:once)
        expect(logger_double).to have_received(:info).with(/es translations have been generated and saved to/)
      end
    end

    context 'with overwrite option' do
      let(:service) { TranslationService.new('es', true) }

      it 'overwrites existing translations and logs the overwrite' do
        service.generate(csv_path.to_s, output_path.to_s)

        yaml_content = YAML.load_file(output_path)
        expect(yaml_content['es']['test']['key2']).to eq('Mundo') # Overwritten

        expect(logger_double).to have_received(:warn).with(/Overwriting existing translation for key/)
        expect(logger_double).not_to have_received(:warn).with(/Collision detected for key/)
      end
    end
  end

  private

  def setup_test_environment
    FileUtils.mkdir_p(tmp_dir)

    @csv_contents = create_mock_csv_file
    create_mock_existing_translations
    create_mock_current_locale_translations

    allow(Rails).to receive(:root).and_return(Pathname.new(tmp_dir))
  end

  def mock_translation_service_methods
    allow_any_instance_of(TranslationService).to receive(:load_existing_translations).and_return(
      YAML.load_file(existing_translations_path)
    )
    allow_any_instance_of(TranslationService).to receive(:load_current_locale_translations).and_return(
      YAML.load_file(current_locale_translations_path)
    )
  end

  def create_mock_csv_file
    contents = [
      %w[key en es],
      %w[en.test.key1 Hello Hola],
      %w[en.test.key2 World Mundo],
      %w[en.test.key3 Skip],
      %w[en.test.key5 Old Value Valor Antiguo]
    ]

    CSV.open(csv_path, 'w') do |csv|
      contents.each { |row| csv << row }
    end

    contents
  end

  def create_mock_existing_translations
    File.write(existing_translations_path, {
      'en' => {
        'test' => {
          'key1' => 'Hello',
          'key2' => 'World',
          'key3' => 'Skip',
          'key4' => 'No Translation',
          'key5' => 'Old Value'
        }
      }
    }.to_yaml)
  end

  def create_mock_current_locale_translations
    File.write(current_locale_translations_path, {
      'es' => {
        'test' => {
          'key1' => 'Hola',
          'key2' => 'Old Mundo',
          'key5' => 'Valor Antiguo'
        }
      }
    }.to_yaml)
  end
end
