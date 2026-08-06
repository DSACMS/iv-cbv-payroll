require "aws-sdk-s3"

class PresignedUploadService
  SERVICE_NAME = ENV["UNSCANNED_BUCKET_NAME"].present? ? :unscanned : :unscanned_local
  MAX_UPLOAD_BYTES = 25.megabytes
  ALLOWED_CONTENT_TYPE = %r{\A(?:image/[a-z0-9.+-]+|application/pdf)\z}
  CHECKSUM_FORMAT = %r{\A[A-Za-z0-9+/]{22}==\z}
  POLICY_TTL = 15.minutes

  class UnacceptableUpload < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("Upload rejected: #{reason}")
    end
  end

  include Rails.application.routes.url_helpers

  def initialize(service: ActiveStorage::Blob.services.fetch(SERVICE_NAME), authenticity_token: nil)
    @service = service
    @authenticity_token = authenticity_token
  end

  def call(files)
    requested = files.map { |file| normalize(file) }
    requested.each { |file| validate!(file) }
    requested.map { |file| presign(file) }
  end

  private

  attr_reader :service, :authenticity_token

  def normalize(file)
    {
      filename: file[:filename].to_s,
      content_type: file[:content_type].to_s,
      byte_size: file[:byte_size].to_i,
      checksum: file[:checksum].to_s
    }
  end

  def presign(file)
    blob = build_blob(file)
    url, fields = destination_for(blob.key, file[:content_type])

    {
      filename: file[:filename],
      url: url,
      fields: fields,
      signed_id: blob.signed_id
    }
  end

  def build_blob(file)
    ActiveStorage::Blob.create!(
      filename: file[:filename],
      content_type: file[:content_type],
      byte_size: file[:byte_size],
      checksum: file[:checksum],
      service_name: SERVICE_NAME,
      metadata: { identified: true, analyzed: true }
    )
  end

  def validate!(file)
    raise UnacceptableUpload, :unsupported_type unless ALLOWED_CONTENT_TYPE.match?(file[:content_type])
    raise UnacceptableUpload, :too_large if file[:byte_size] > MAX_UPLOAD_BYTES
    raise UnacceptableUpload, :empty unless file[:byte_size].positive?
    raise UnacceptableUpload, :upload_failed unless CHECKSUM_FORMAT.match?(file[:checksum])
  end

  def destination_for(key, content_type)
    if service.respond_to?(:bucket)
      config = service.client.client.config

      post = Aws::S3::PresignedPost.new(
        config.credentials,
        config.region,
        service.bucket.name,
        key: key,
        content_type: content_type,
        content_length_range: 0..MAX_UPLOAD_BYTES,
        signature_expiration: POLICY_TTL.from_now
      )
      [ post.url, post.fields ]
    else
      [
        activities_flow_local_uploads_path,
        {
          "key" => key,
          "Content-Type" => content_type,
          "authenticity_token" => authenticity_token
        }.compact
      ]
    end
  end
end
