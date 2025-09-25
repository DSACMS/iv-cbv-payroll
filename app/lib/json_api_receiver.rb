require "sinatra"
require "json"

class JsonApiReceiver < Sinatra::Base
  post "/" do
    content_type :json

    request.body.rewind
    body = request.body.read

    puts "Received JSON: #{body}"

    begin
      JSON.parse(body)
      { status: "success" }.to_json
    rescue JSON::ParserError
      status 400
      { error: "Invalid JSON" }.to_json
    end
  end
end
