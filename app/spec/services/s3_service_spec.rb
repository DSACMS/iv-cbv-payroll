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
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:test_file_path) { tmp_directory.join('test_file.txt').to_s }

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
