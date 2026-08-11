require "rails_helper"

RSpec.describe S3Service do
  let(:bucket_name) { "test-bucket" }
  let(:config) { { "bucket" => bucket_name } }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:transfer_manager) { instance_double(Aws::S3::TransferManager) }
  let(:s3_service) { described_class.new(config) }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::TransferManager).to receive(:new)
      .with(client: s3_client)
      .and_return(transfer_manager)
  end

  describe "#initialize" do
    it "raises a clear error when the bucket is blank" do
      expect { described_class.new({ "bucket" => nil }) }
        .to raise_error(ArgumentError, "S3 bucket is required")
    end
  end

  describe "#upload_file" do
    it "uploads one file with the existing API" do
      file_name = "outfiles/report.gpg"

      Tempfile.create do |file|
        file.write("file content")
        file.rewind

        expect(s3_client).to receive(:put_object).with(
          bucket: bucket_name,
          key: file_name,
          body: instance_of(File)
        )

        s3_service.upload_file(file.path, file_name)
      end
    end
  end

  describe "#download_file" do
    it "downloads one object to the requested path" do
      object_key = "active-storage-key"
      file_path = "/tmp/document.pdf"

      expect(transfer_manager).to receive(:download_file).with(
        file_path,
        bucket: bucket_name,
        key: object_key
      )

      s3_service.download_file(object_key, file_path)
    end
  end

  describe "#upload_directory" do
    it "uploads the directory with a destination prefix" do
      directory = "/tmp/transmission"
      s3_prefix = "outfiles/SANDBOX123/"

      expect(transfer_manager).to receive(:upload_directory).with(
        directory,
        bucket: bucket_name,
        s3_prefix: s3_prefix,
        ignore_failure: false
      )

      s3_service.upload_directory(directory, s3_prefix)
    end
  end
end
