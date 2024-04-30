# frozen_string_literal: true
require "faraday"

class ArgyleService
  def initialize(api_key)
    @api_key = api_key
    base_url = ENV["ARGYLE_API_URL"] || "https://api-sandbox.argyle.com/v2"
    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      url: base_url,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Basic #{@api_key}"
      }
    }
    @http = Faraday.new(client_options)
  end

  # Fetch all Argyle items
  def items(query = nil)
    # get "items" and pass the query as the q parameter for the Faraday instance
    response = @http.get("items", { q: query })
    JSON.parse(response.body)
  end
end
