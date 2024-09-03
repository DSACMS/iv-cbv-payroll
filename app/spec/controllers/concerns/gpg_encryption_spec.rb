require 'rails_helper'
require 'tempfile'
require 'zlib'

RSpec.describe GpgEncryptable do
  include_context "gpg_setup"

  let(:gpg_encryptable_test_class) { Class.new { include GpgEncryptable; include TarFileCreatable } }
  let(:class_instance) { gpg_encryptable_test_class.new }
  let(:tmp_directory) { Rails.root.join('tmp') }
  let(:test_file_content) { "This is a test file content" }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }
  let(:tar_file_path) { tmp_directory.join('test_file.tar').to_s }
  let(:encrypted_tar_file_path) { "#{tar_file_path}.gpg" }
  let(:untar_file_path) { File.join(tmp_directory, "#{SecureRandom.uuid}-untarred") }
  let(:encrypted_file_path) { "#{test_file_path}.gpg" }

  after(:each) do
    File.delete(test_file_path) if File.exist?(test_file_path)
    File.delete(encrypted_file_path) if File.exist?(encrypted_file_path)
    File.delete(tar_file_path) if File.exist?(tar_file_path)
    File.delete(encrypted_tar_file_path) if File.exist?(encrypted_tar_file_path)
    FileUtils.remove_entry untar_file_path if File.exist?(untar_file_path)
  end

  describe '#gpg_encrypt_file' do
    before do
      File.write(test_file_path, test_file_content)
    end

    it 'encrypts the file' do
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
      # Create the tar file with the test content
      tmp_tar = class_instance.create_tar_file([ { name: 'test_file.txt', content: test_file_content } ])
      expect(File.exist?(tmp_tar.path)).to be true

      # Encrypt the tar file
      encrypted_tar_file_path = class_instance.gpg_encrypt_file(tmp_tar.path, @public_key)
      encrypted_content = File.read(encrypted_tar_file_path)
      expect(encrypted_content).not_to be_empty

      # Decrypt the file and verify its contents
      crypto = GPGME::Crypto.new

      # Write the decrypted tar file to the tmp directory
      FileUtils.mkdir_p(untar_file_path)
      decrypted_tar_file_path = File.join(untar_file_path, "#{SecureRandom.uuid}.tar")
      File.write(decrypted_tar_file_path, decrypted_content)

      # Untar the decrypted content
      class_instance.untar_file(decrypted_tar_file_path, untar_file_path)

      # Verify the contents of the untarred files
      untarred_file_path = File.join(untar_file_path, 'test_file.txt')
      expect(File.exist?(untarred_file_path)).to be true
      untarred_content = File.read(untarred_file_path)
      expect(untarred_content).to eq(test_file_content)
    end

    after do
      File.delete(test_file_path) if File.exist?(test_file_path)
    end
  end
end
