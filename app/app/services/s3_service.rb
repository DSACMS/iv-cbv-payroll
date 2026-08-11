require "aws-sdk-s3"

class S3Service
  def initialize(config)
    @bucket_name = config.fetch("bucket")
    raise ArgumentError, "S3 bucket is required" if @bucket_name.blank?
  end

  def upload_file(file_path, file_name)
    File.open(file_path, "rb") do |file|
      s3_client.put_object(bucket: @bucket_name, key: file_name, body: file)
    end
  end

  def download_file(file_name, file_path)
    transfer_manager.download_file(file_path, bucket: @bucket_name, key: file_name)
  end

  def upload_directory(directory, s3_prefix)
    transfer_manager.upload_directory(
      directory,
      bucket: @bucket_name,
      s3_prefix: s3_prefix,
      ignore_failure: false
    )
  end

  private

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def transfer_manager
    @transfer_manager ||= Aws::S3::TransferManager.new(client: s3_client)
  end
end
