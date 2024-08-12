require "aws-sdk-rails"
require "gpgme"

class S3Service
  def initialize(config)
    @bucket_name = config["bucket_name"]
    @access_key_id = config["access_key_id"]
    @secret_access_key = config["secret_access_key"]
    @region = config["region"]
    @public_key = config["public_key"]
  end

  def encrypt_and_upload(file_path, file_name)
    encrypted_file_path = encrypt_file(file_path)
    upload_file(encrypted_file_path, file_name)
    File.delete(encrypted_file_path)
  end

  private

  def encrypt_file(file_path)
    GPGME::Key.import(@public_key)
    crypto = GPGME::Crypto.new

    encrypted_file_path = "#{file_path}.gpg"
    File.open(encrypted_file_path, "wb") do |output|
      crypto.encrypt File.open(file_path, "rb"), recipients: @public_key, output: output
    end

    encrypted_file_path
  end

  def upload_file(file_path, file_name)
    s3_client = Aws::S3::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(@access_key_id, @secret_access_key)
    )

    File.open(file_path, "rb") do |file|
      s3_client.put_object(bucket: @bucket_name, key: file_name, body: file)
    end
  end
end
