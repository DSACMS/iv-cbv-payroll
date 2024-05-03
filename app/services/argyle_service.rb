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
    # get "items" and pass the query as the q parameter for the Faraday instance
    response = @http.get("items", { q: query })
    JSON.parse(response.body)
  end

  def payroll_documents(account_id, user_id)
    # Check if the ConnectedArgyleAccount exists for the given user_id and account_id
    account_exists = ConnectedArgyleAccount.exists?(user_id: user_id, account_id: account_id)

    # Proceed with the HTTP request only if the account exists
    if account_exists
      response = @http.get("payroll-documents", { account: account_id, user: user_id })
      JSON.parse(response.body)
    else
      # Return an appropriate message or handle the logic when the account does not exist
      { error: "No matching account found for the provided user_id and account_id." }
    end
  end

end
