require 'rails_helper'
require 'gpgme'

RSpec.describe S3Service do
  let(:tmp_directory) { Rails.root.join('tmp') }
  let(:config) do
    {
      "bucket_name" => "test-bucket",
      "access_key_id" => "test-access-key",
      "secret_access_key" => "test-secret-key",
      "region" => "us-east-2"
    }
  end
  let(:s3_service) { S3Service.new(config) }
  let(:file_content) { "This is a test file content" }
  let(:file_name) { 'encrypted_test_file.gpg' }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }
  let(:encrypted_file_path) { "#{test_file_path}.gpg" }
  let(:s3_client) { instance_double(Aws::S3::Client) }

  before(:all) do
    # Ensure that generated gpg keys are within the rails tmp dir
    @original_gpg_home = ENV['GNUPGHOME']
    ENV['GNUPGHOME'] = Rails.root.join('tmp', 'gpghome').to_s
    FileUtils.mkdir_p(ENV['GNUPGHOME'])

    # Generate a new key pair non-interactively
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

  let(:public_key) do
    GPGME::Key.find(:public, 'test@example.com').first.export(armor: true)
  end

  let(:config_with_key) { config.merge("public_key" => public_key) }
  let(:s3_service_with_key) { S3Service.new(config_with_key) }

  describe '#encrypt_and_upload' do
    before do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:put_object)
    end

    it 'encrypts and uploads the file' do
      File.write(test_file_path, file_content)

      expect(s3_client).to receive(:put_object).with(
        bucket: config["bucket_name"],
        key: file_name,
        body: instance_of(File)
      )

      s3_service_with_key.encrypt_and_upload(test_file_path, file_name)

      # Verify that the uploaded file is encrypted
      expect(File.exist?(encrypted_file_path)).to be true
      encrypted_content = File.read(encrypted_file_path)
      expect(encrypted_content).not_to include(file_content)
    end
  end

  describe 'private methods' do
    describe '#encrypt_file' do
      it 'encrypts the file content' do
        File.write(test_file_path, file_content)

        encrypted_file_path = s3_service_with_key.send(:gpg_encrypt_file, test_file_path)

        expect(File.exist?(encrypted_file_path)).to be true
        encrypted_content = File.read(encrypted_file_path)
        expect(encrypted_content).not_to include(file_content)

        # Decrypt the file and verify its contents
        crypto = GPGME::Crypto.new
        decrypted_content = crypto.decrypt(encrypted_content).to_s
        expect(decrypted_content).to eq(file_content)
      end
    end

    describe '#upload_file' do
      let(:s3_client) { instance_double(Aws::S3::Client) }

      before do
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      end

      it 'uploads the file to S3' do
        File.write(test_file_path, file_content)

        expect(s3_client).to receive(:put_object).with(
          bucket: config["bucket_name"],
          key: file_name,
          body: instance_of(File)
        )

        s3_service.send(:upload_file, test_file_path, file_name)
      end
    end
  end
end
