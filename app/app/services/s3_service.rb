# @see: https://github.com/ueno/ruby-gpgme
require "gpgme"
require "aws-sdk-s3"

class S3Service
  def initialize(config)
    @bucket_name = config["bucket"]
  end

  def upload_file(file_path, file_name)
    s3_client = Aws::S3::Client.new

    File.open(file_path, "rb") do |file|
      s3_client.put_object(bucket: @bucket_name, key: file_name, body: file)
    end
  end
end
