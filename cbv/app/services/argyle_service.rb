# frozen_string_literal: true

require "faraday"

class ArgyleService
  def initialize
    @api_key = Rails.application.credentials.argyle[:api_key]
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
    response = @http.get("items", { q: query })
    JSON.parse(response.body)
  end

  def payroll_documents(account_id, user_id)
    account_exists = ConnectedArgyleAccount.exists?(user_id: user_id, account_id: account_id)
    raise "Argyle error: Account not connected" unless account_exists
    response = @http.get("payroll-documents", { account: account_id, user: user_id })
    JSON.parse(response.body)
  end
end
