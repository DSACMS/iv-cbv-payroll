require 'rails_helper'
require 'tempfile'

RSpec.describe GpgEncryptable do
  let(:gpg_encryptable_test_class) { Class.new { include GpgEncryptable } }
  let(:class_instance) { gpg_encryptable_test_class.new }
  let(:tmp_directory) { Rails.root.join('tmp') }
  let(:test_file_content) { "This is a test file content" }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }
  let(:encrypted_file_path) { "#{test_file_path}.gpg" }
  let(:public_key) { File.read(Rails.root.join('app', 'spec', 'support', 'fixtures', 'gpg', 'test_public_key.asc')) }

  after(:each) do
    File.delete(test_file_path) if File.exist?(test_file_path)
    File.delete(encrypted_file_path) if File.exist?(encrypted_file_path)
  end

  describe '#gpg_encrypt_file' do
    before do
      class_instance.public_key = public_key
    end

    it 'encrypts the file content' do
      File.write(test_file_path, test_file_content)

      encrypted_file_path = class_instance.gpg_encrypt_file(test_file_path)

      expect(File.exist?(encrypted_file_path)).to be true
      encrypted_content = File.read(encrypted_file_path)
      expect(encrypted_content).not_to include(test_file_content)

      # Decrypt the file and verify its contents
      crypto = GPGME::Crypto.new
      decrypted_content = crypto.decrypt(encrypted_content).to_s
      expect(decrypted_content).to eq(test_file_content)
    end
  end

  describe '#import_key' do
    it 'imports a valid GPG key' do
      expect { class_instance.send(:import_key, public_key) }.not_to raise_error
    end

    it 'raises an error for an invalid GPG key' do
      invalid_key = "Invalid key data"
      expected_error = "Invalid GPG key: The provided key data is not valid"
      expect { class_instance.send(:import_key, invalid_key) }.to raise_error(RuntimeError, expected_error)
    end
  end
end
