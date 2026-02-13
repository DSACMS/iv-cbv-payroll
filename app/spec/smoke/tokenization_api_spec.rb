require_relative "smoke_helper"

RSpec.describe "Tokenization API", type: :feature do
  it "creates an invitation via POST /api/v1/invitations" do
    result = create_invitation_via_api(
      params: {
        language: "en",
        agency_partner_metadata: {
          first_name: "Smoke",
          last_name: "Test",
          case_number: "SMOKE-#{Time.now.to_i}",
          date_of_birth: "1990-01-15"
        }
      }
    )

    expect(result).to have_key("tokenized_url")
    expect(result["tokenized_url"]).to include("/start/")
    expect(result).to have_key("expiration_date")
    $stderr.puts "[SMOKE] Tokenized URL: #{result['tokenized_url']}"
  end

  it "can visit the tokenized link and reach the entry page" do
    result = create_invitation_via_api(
      params: {
        language: "en",
        agency_partner_metadata: {
          first_name: "Smoke",
          last_name: "Test",
          case_number: "SMOKE-#{Time.now.to_i}",
          date_of_birth: "1990-01-15"
        }
      }
    )

    page.driver.browser.navigate.to(result["tokenized_url"])
    smoke_verify_page(title: "Let's verify your income")
    expect(page).to have_current_path(%r{/cbv/}, url: true)
  end
end
