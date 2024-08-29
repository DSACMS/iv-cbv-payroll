require 'rails_helper'
require 'tempfile'

RSpec.describe GpgEncryptable do
  let(:gpg_encryptable_test_class) { Class.new { include GpgEncryptable } }
  let(:class_instance) { gpg_encryptable_test_class.new }
  let(:tmp_directory) { Rails.root.join('tmp') }
  let(:test_file_content) { "This is a test file content" }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }
  let(:encrypted_file_path) { "#{test_file_path}.gpg" }
  let(:public_key) do
    GPGME::Key.find(:public, 'test@example.com').first.export(armor: true)
  end

  before(:all) do
    @original_gpg_home = ENV['GNUPGHOME']
    ENV['GNUPGHOME'] = Rails.root.join('tmp', 'gpghome').to_s
    FileUtils.mkdir_p(ENV['GNUPGHOME'])

    key_script = <<-SCRIPT
      %echo Generating a basic OpenPGP key
      Key-Type: RSA
      Key-Length: 2048
      Subkey-Type: RSA
      Subkey-Length: 2048
      Name-Real: Test User
      Name-Email: test@example.com
      Expire-Date: 0
      %no-protection
      %commit
      %echo done
    SCRIPT

    IO.popen('gpg --batch --generate-key', 'r+') do |io|
      io.write(key_script)
      io.close_write
      io.read
    end
  end

  after(:all) do
    FileUtils.remove_entry ENV['GNUPGHOME']
    ENV['GNUPGHOME'] = @original_gpg_home
  end

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

      encrypted_file_path = class_instance.gpg_encrypt_file(test_file_path, public_key)

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
      expect { class_instance.send(:import_key, invalid_key) }.to raise_error(RuntimeError, "Invalid GPG key: The provided key data is not valid")
    end
  end
end

