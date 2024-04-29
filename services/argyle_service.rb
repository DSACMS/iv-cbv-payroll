# frozen_string_literal: true
require 'net/http'
require 'logger'
class ArgyleService
  ARGYLE_BASE_URL = 'https://api.argyle.com/v2/'

  def initialize(api_key)
    @api_key = api_key
    @uri = URI(ARGYLE_BASE_URL)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = (@uri.scheme == 'https')
  end

  # Fetch all Argyle items
  def items(query = nil)
    uri = URI("#{ARGYLE_BASE_URL}/items?q=#{query}")
    make_request(uri)
  end

  private

  # Helper method to make the HTTP GET request
  def make_request(uri)
    request = Net::HTTP::Get.new(uri)
    request['accept'] = 'application/json'
    request['content-type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"

    response = Net::HTTP.start(@url.host, @url.port) {|request|
      @http.start(request)
    }
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue JSON::ParserError => e
    # Handle JSON parsing errors
    { error: 'Invalid JSON format', details: e.message }
  rescue StandardError => e
    # Handle other errors, like network issues
    { error: 'An Error Has Occurred', details: e.message }
  end
end