#!/usr/bin/env ruby
#
# This API receiver logs JSON POST requests on port 4567 and verifies HMAC-sha512 signatures.
#
# To run the server, see the instructions in CONTRIBUTING.md ("JSON API Testing").
#

require "sinatra"
require "fileutils"
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
  post "/documents" do
    content = request.body.read
    unless valid_signature?(content)
      puts "❌ Invalid signature"
      halt 401, { error: "Unauthorized" }.to_json
    end

    filename = File.basename(request.env.fetch("HTTP_CONTENT_DISPOSITION", "")[/filename="([^"]+)"/, 1].to_s)
    halt 400, { error: "Missing document filename" }.to_json if filename.empty?

    directory = File.expand_path("../tmp/transmitted_documents", __dir__)
    FileUtils.mkdir_p(directory)
    file_path = File.join(directory, filename)
    File.binwrite(file_path, content)
    puts "Document written successfully to #{file_path}"
    status 200
  rescue => e
    puts "Error writing document: #{e.message}"
    status 500
  end

  post "/activities" do
    content_type :json

    request.body.rewind
    body = request.body.read

    puts "Received CE activity JSON: #{body}"

    unless valid_signature?(body)
      puts "❌ Invalid signature"
      halt 401, { error: "Unauthorized" }.to_json
    end
    puts "✅ Verified signature"

    begin
      report = JSON.parse(body)
    rescue JSON::ParserError
      status 400
      return { error: "Invalid JSON" }.to_json
    end

    file_path = File.expand_path("../tmp/transmitted_activity_report.json", __dir__)
    File.write(file_path, JSON.pretty_generate(report))
    puts "CE activity report written successfully to #{file_path}"

    {
      status: "received",
      confirmation_code: report["confirmation_code"],
      received_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      schema_version_received: report["schema_version"],
      unrecognized_fields_detected: false
    }.to_json
  end

  post "/pdf" do
    pdf_content = request.body.read

    begin
      file_path = File.expand_path("../tmp/transmitted_pdf.pdf", __dir__)
      File.open(file_path, "wb") do |file|
        file.write(pdf_content)
      end
      puts "PDF written successfully to #{file_path}"
      status 200
    rescue => e
      puts "Error writing PDF file: #{e.message}"
      status 500
    end
  end

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
      unless valid_signature?(body)
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

  def valid_signature?(body)
    signature = request.env["HTTP_X_IVAAS_SIGNATURE"]
    timestamp = request.env["HTTP_X_IVAAS_TIMESTAMP"]
    return false unless signature && timestamp

    JsonApiSignature.verify(body, timestamp, signature, ENV.fetch("JSON_API_KEY", "your-api-key-here"))
  end

  run! if __FILE__ == $0
end
