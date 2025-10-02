require "sinatra"
require "json"
require_relative "../config/environment"
require_relative "../app/services/json_api_signature"

class JsonApiReceiver < Sinatra::Base
  # For the reference implementation, we'll use a simple test key
  API_KEY = "test-api-key"

  post "/" do
    content_type :json

    request.body.rewind
    body = request.body.read
    signature = request.env["HTTP_X_IVAAS_SIGNATURE"]
    timestamp = request.env["HTTP_X_IVAAS_TIMESTAMP"]

    puts "Received JSON: #{body}"

    if signature && timestamp
      unless JsonApiSignature.verify(body, timestamp, signature, API_KEY)
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
