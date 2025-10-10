#!/usr/bin/env ruby
#
# API receiver with signature verification
#
# This receiver logs JSON POST requests on port 4567 and verifies HMAC-sha512 signatures.
#
# Dependencies: gem install sinatra
#
# Usage:
#   JSON_API_KEY=your-api-key ruby json_api_receiver.rb

require "sinatra"
require "json"
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
    signature == expected_signature
  end
end

class JsonApiReceiver < Sinatra::Base
  post "/" do
    content_type :json

    request.body.rewind
    body = request.body.read
    signature = request.env["HTTP_X_IVAAS_SIGNATURE"]
    timestamp = request.env["HTTP_X_IVAAS_TIMESTAMP"]

    puts "Received JSON: #{body}"

    puts "Headers:"
    request.env.each do |key, value|
      puts "  #{key}: #{value}" if key.start_with?("HTTP_")
    end

    if signature && timestamp
      api_key = ENV.fetch("JSON_API_KEY", "your-api-key-here")

      unless JsonApiSignature.verify(body, timestamp, signature, api_key)
        puts "❌ Invalid signature"
        status 401
        return { error: "Unauthorized" }.to_json
      end
      puts "✅ Verified signature"
    else
      puts "⚠️  No signature headers found - skipping verification"
    end

    begin
      JSON.parse(body)
      { status: "success" }.to_json
    rescue JSON::ParserError
      status 400
      { error: "Invalid JSON" }.to_json
    end
  end

  run! if __FILE__ == $0
end
