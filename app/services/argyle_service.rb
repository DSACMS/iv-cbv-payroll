# frozen_string_literal: true
require 'net/http'
require 'logger'
require 'faraday'

class ArgyleService
  ARGYLE_BASE_URL = 'https://api-sandbox.argyle.com/v2/'

  def initialize(api_key)
    @api_key = api_key
    @url = URI.parse(ARGYLE_BASE_URL)
    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      ssl: {
        verify: @url.scheme == 'https'
      },
      url: ARGYLE_BASE_URL,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization ' => "Bearer #{@api_key}"
      },
    }

    @http = Faraday.new(client_options)
  end

  # Fetch all Argyle items
  def items(query = nil)
    # get "items" and pass the query as the q parameter for the Faraday instance
    response = @http.get('items', { q: query })
    JSON.parse(response.body)
  end
end