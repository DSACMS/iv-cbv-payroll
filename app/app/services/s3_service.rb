# @see: https://github.com/ueno/ruby-gpgme
require "gpgme"
require "aws-sdk-s3"

class S3Service
  def initialize(config)
    @bucket_name = config["bucket_name"]
    @access_key_id = config["access_key_id"]
    @secret_access_key = config["secret_access_key"]
    @region = config["region"]
    @public_key = config["public_key"]
  end

  def encrypt_and_upload(file_path, file_name)
    encrypted_file_path = gpg_encrypt_file(file_path)
    upload_file(encrypted_file_path, file_name)
  end


  def gpg_encrypt_file(file_path)
    import_key(@public_key)
    crypto = GPGME::Crypto.new
    recipient = GPGME::Key.find(:public, @public_key).first
    encrypted_file_path = "#{file_path}.gpg"
    File.open(encrypted_file_path, "wb") do |output|
      crypto.encrypt File.open(file_path, "rb"), recipients: recipient, output: output
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

  private

  def import_key(key_data)
    unless GPGME::Key.valid?(key_data)
      raise "Invalid GPG key: The provided key data is not valid"
    end
    GPGME::Key.import(key_data)
  end
end
