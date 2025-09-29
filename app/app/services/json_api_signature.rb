require "openssl"

class JsonApiSignature
  def self.generate(body, timestamp, api_key)
    payload = "#{timestamp}:#{body}"
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha512"),
      api_key.encode("utf-8"),
      payload
    )
  end

  def self.verify(body, timestamp, signature, api_key)
    expected_signature = generate(body, timestamp, api_key)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end
end
