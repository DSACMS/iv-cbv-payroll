require 'billy/capybara/rspec'

module E2eTestHelpers
  def verify_page(page, title:, wait: Capybara.default_max_wait_time)
    expect(page).to have_content(title, wait: wait)

    # Verify page has no missing translations
    Capybara.using_wait_time(0) do
      missing_translations = page.all("span", class: "translation_missing")
      raise(<<~ERROR) if missing_translations.any?
        E2E test failed on #{page.current_url}:

        #{missing_translations.map { |el| el["title"] }}
      ERROR
    end
  end

  HARDCODED_ACCOUNT_ID = "5a8cfb92-3373-4e65-b41b-54e821e79671"
  HARDCODED_PLATFORM_ID = "5965580e-380f-4b86-8a8a-7278c77f73cb"

  def simulate_next_step_and_webhooks
    Billy.proxy.stub(%r{ui/step_result}, method: "get").and_return(headers: {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
    },
                                                             json: {
                                                               "data": {
                                                                 "response_type": "success",
                                                                 "account_id": HARDCODED_ACCOUNT_ID,
                                                                 "masked_accounts":  nil
                                                               }
                                                             }
    )
    simulate_account_added_event(CbvFlow.last)
  end

  def simulate_account_added_event(cbv_flow)
    pinwheel = Aggregators::Sdk::PinwheelService.new("sandbox")
    @payroll_account = cbv_flow.payroll_accounts.find_or_create_by(type: :pinwheel, pinwheel_account_id: HARDCODED_ACCOUNT_ID) do |new_payroll_account|
      new_payroll_account.supported_jobs = pinwheel.fetch_platform(platform_id: HARDCODED_PLATFORM_ID)["data"]["supported_jobs"]
    end


    @webhook_event = WebhookEvent.create!(
      payroll_account: @payroll_account,
      event_name: "account.added",
      event_outcome: "success",
      )
  end

  def mock_cbv_flow_responses
    headahs = {
      'Access-Control-Allow-Origin' => 'https://cdn.getpinwheel.com',
      'Access-Control-Allow-Credentials' => 'true',
      "My-Awesome-Debug-Headah" => "IM WALKING HERE",
      'Access-Control-Allow-Methods' => 'DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT',
      'Access-Control-Allow-Headers' => 'content-type,dersh-id,login_attempt_id,modal_session_id,pinwheel-link-token,unique_user_id,x-ct,x-sdk,x-sdk-version'
    }
    Billy.proxy.stub(/step_result/, method: "options").and_return(headers: headahs, body: "OK", code: 200)
    Billy.proxy.stub(/ui\/next/, method: "options").and_return(headers: headahs, body: "OK", code: 200)
    Billy.proxy.stub(/step_result/).and_return(headers: {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
    },
                                               json: {
                                                 "data": {
                                                   "response_type": "next",
                                                   "template": {
                                                     "template_type": "form",
                                                     "fields": [
                                                       {
                                                         "key": "username",
                                                         "field_type": "text",
                                                         "field_subtype": "plaintext",
                                                         "label": "Username",
                                                         "locked_field": false,
                                                         "min_length": nil,
                                                         "max_length": nil,
                                                         "pattern": nil,
                                                         "placeholder": nil,
                                                         "options": nil,
                                                         "payload": nil,
                                                         "hint": nil,
                                                         "initial_value": nil,
                                                         "should_obfuscate": false
                                                       },
                                                       {
                                                         "key": "password",
                                                         "field_type": "text",
                                                         "field_subtype": "password",
                                                         "label": "Password",
                                                         "locked_field": false,
                                                         "min_length": nil,
                                                         "max_length": nil,
                                                         "pattern": nil,
                                                         "placeholder": nil,
                                                         "options": nil,
                                                         "payload": nil,
                                                         "hint": nil,
                                                         "initial_value": nil,
                                                         "should_obfuscate": true
                                                       }
                                                     ],
                                                     "title": "Log into your payroll account",
                                                     "subtitle": "Enter your login credentials to continue",
                                                     "text_list": [],
                                                     "actions": [],
                                                     "button_text": nil
                                                   }
                                                 }
                                               }






    )
    Billy.proxy.stub(%r{ui/next}, method: "post").and_return(headers: {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
    },
                                                             json: {
                                                               "data": {
                                                                 "response_type": "processing",
                                                                 "title": nil,
                                                                 "subtitle": nil
                                                               }
                                                             }
    )
  end
end
