require 'rails_helper'
require 'yaml'

RSpec.describe TranslationService do
  let(:tmp_dir) { Rails.root.join('tmp', 'spec') }
  let(:csv_path) { tmp_dir.join('translations.csv') }
  let(:output_path) { tmp_dir.join('test_translations.yml') }
  let(:metadata_dir) { tmp_dir.join('locale_imports') }
  let(:existing_translations_path) { tmp_dir.join('en.yml') }
  let(:current_locale_translations_path) { tmp_dir.join('es.yml') }
  let(:csv_contents) { @csv_contents }

  before do
    setup_test_environment
    mock_translation_service_methods
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe '#generate' do
    context 'with default options' do
      let(:service) { TranslationService.new }

      it 'generates a YAML file with Spanish translations' do
        result = service.generate(csv_path.to_s, output_path.to_s)

        expect(File.exist?(output_path)).to be true
        yaml_content = YAML.load_file(output_path)

        expect(yaml_content).to eq(result)
        expect(yaml_content).to have_key('es')
        expect(yaml_content['es']['test']['key1']).to eq('Hola')
        expect(yaml_content['es']['test']['key2']).to eq('Old Mundo') # Not overwritten
        expect(yaml_content['es']['test']).not_to have_key('key3')
        expect(yaml_content['es']['test']).not_to have_key('key4')
      end

      it 'generates a metadata file' do
        service.generate(csv_path.to_s, output_path.to_s)

        metadata_files = Dir.glob(File.join(metadata_dir, 'es_import_*.txt'))
        expect(metadata_files.size).to eq(1)

        metadata_content = File.read(metadata_files.first)
        expect(metadata_content).to include('Successfully Imported: 0')
        expect(metadata_content).to include('Empty Rows: 0')
        expect(metadata_content).to include('Skipped Rows: 1')
        expect(metadata_content).to include('Collisions: 1')
        expect(metadata_content).to include('Failed Imports: 0')
        expect(metadata_content).to include("Total Entries: 2")
      end
    end

    context 'with overwrite option' do
      let(:service) { TranslationService.new('es', true) }

      it 'overwrites existing translations' do
        result = service.generate(csv_path.to_s, output_path.to_s)

        yaml_content = YAML.load_file(output_path)
        expect(yaml_content['es']['test']['key2']).to eq('Mundo') # Overwritten
      end
    end
  end

  private

  def setup_test_environment
    FileUtils.mkdir_p(tmp_dir)
    FileUtils.mkdir_p(metadata_dir)

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
      [ 'en.test.key1', 'Hello', 'Hola' ],
      [ 'en.test.key2', 'World', 'Mundo' ],
      [ 'en.test.key3', 'Skip', '' ]
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
          'key4' => 'No Translation'
        }
      }
    }.to_yaml)
  end

  def create_mock_current_locale_translations
    File.write(current_locale_translations_path, {
      'es' => {
        'test' => {
          'key1' => 'Hola',
          'key2' => 'Old Mundo'
        }
      }
    }.to_yaml)
  end
end
