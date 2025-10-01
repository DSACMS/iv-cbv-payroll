require "sinatra"
require "json"
require_relative "../config/environment"
require_relative "../app/services/json_api_signature"

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
      agency_id = ENV.fetch("JSON_API_AGENCY", "sandbox")
      api_key = User.api_key_for_agency(agency_id)
      unless api_key
        puts "❌ No API key found in database"
        status 500
        return { error: "Server configuration error" }.to_json
      end

      unless JsonApiSignature.verify(body, timestamp, signature, api_key)
        puts "❌ Invalid signature"
        status 401
        return { error: "Unauthorized" }.to_json
      end
      puts "✅ Verified signature"
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
