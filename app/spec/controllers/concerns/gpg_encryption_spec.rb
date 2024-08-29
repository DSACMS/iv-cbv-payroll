require 'rails_helper'
require 'tempfile'
require 'zlib'

RSpec.describe GpgEncryptable do
  let(:gpg_encryptable_test_class) { Class.new { include GpgEncryptable; include TarFileCreatable } }
  let(:class_instance) { gpg_encryptable_test_class.new }
  let(:tmp_directory) { Rails.root.join('tmp') }
  let(:test_file_content) { "This is a test file content" }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }
  let(:tar_file_path) { tmp_directory.join('test_file.tar').to_s }
  let(:encrypted_tar_file_path) { "#{tar_file_path}.gpg" }
  let(:untar_file_path) { File.join(tmp_directory, 'untarred') }

  let(:encrypted_file_path) { "#{test_file_path}.gpg" }

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

    @public_key = GPGME::Key.find(:public, 'test@example.com').first.export(armor: true)
  end

  after(:all) do
    FileUtils.remove_entry ENV['GNUPGHOME']
    ENV['GNUPGHOME'] = @original_gpg_home
  end

  after(:each) do
    File.delete(test_file_path) if File.exist?(test_file_path)
    File.delete(encrypted_file_path) if File.exist?(encrypted_file_path)
    File.delete(tar_file_path) if File.exist?(tar_file_path)
    File.delete(encrypted_tar_file_path) if File.exist?(encrypted_tar_file_path)
    FileUtils.remove_entry untar_file_path if File.exist?(untar_file_path)
  end

  describe '#gpg_encrypt_file' do
    it 'encrypts the file content' do
      File.write(test_file_path, test_file_content)

      encrypted_file_path = class_instance.gpg_encrypt_file(test_file_path, @public_key)

      expect(File.exist?(encrypted_file_path)).to be true
      encrypted_content = File.read(encrypted_file_path)
      expect(encrypted_content).not_to include(test_file_content)

      # Decrypt the file and verify its contents
      crypto = GPGME::Crypto.new
      decrypted_content = crypto.decrypt(encrypted_content).to_s
      expect(decrypted_content).to eq(test_file_content)
    end

    it 'encrypts the tar file and can decrypt the tar file' do
      File.write(test_file_path, test_file_content)
      expect(File.exist?(test_file_path)).to be true

      # tar the test file
      class_instance.create_tar_file(tar_file_path, [ test_file_path ])
      expect(File.exist?(tar_file_path)).to be true

      # Encrypt the tar file
      encrypted_tar_file_path = class_instance.gpg_encrypt_file(tar_file_path, @public_key)
      encrypted_content = File.read(encrypted_tar_file_path)
      expect(encrypted_content).not_to be_empty

      # Decrypt the file and verify its contents
      crypto = GPGME::Crypto.new
      decrypted_content = crypto.decrypt(encrypted_content).to_s

      # Untar the decrypted content
      FileUtils.mkdir_p(untar_file_path)
      class_instance.untar_file(decrypted_content, untar_file_path)

      # Verify the contents of the untarred files
      untarred_file_path = File.join(untar_file_path, 'test_file.txt')
      expect(File.exist?(untarred_file_path)).to be true
      untarred_content = File.read(untarred_file_path)
      expect(untarred_content).to eq(test_file_content)
    end
  end
end
