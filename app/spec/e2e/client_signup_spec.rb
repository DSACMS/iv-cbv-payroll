require 'rails_helper'

RSpec.describe 'User Steps through signing up', type: :system do
  before do
    driven_by(:selenium_chrome_headless) # Change to :selenium_chrome if you want to see the browser
    WebMock.disable_net_connect!(allow_localhost: true)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:sandbox] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: '123456',
      info: {
        email: 'test@example.com',
        name: 'Test User',
        nickname: 'the mockiest perrson'
      },
      credentials: {
        token: 'mock_token',
        refresh_token: 'mock_refresh_token',
        expires_at: Time.now + 1.hour
      }
    )
  end


  it 'tries to sign up a new person through the flow' do
    visit "sandbox/sso"
    click_on "Continue to CBV Test Agency log in page"
    click_on "Create a new invitation"
    fill_in "cbv_flow_invitation[cbv_applicant_attributes][first_name]", with: "Dean"
    fill_in "Client's middle name", with: "Alan"
    fill_in "cbv_flow_invitation[cbv_applicant_attributes][last_name]", with: "Venture"
    fill_in "Case Number", with: "Some kinda case"
    fill_in "Your WELID", with: "12345"
    fill_in "Client's email address", with: "hank@example.com"
    click_on "Send Invitation"
    expect(page).to have_content "In what language should we send the invitation?"
    find(".usa-radio-group .usa-radio__label[for='language-en-0']").click
    click_on "Send Invitation"
    expect(page).to have_content "Successfully delivered invitation to hank@example.com"
  end
end
