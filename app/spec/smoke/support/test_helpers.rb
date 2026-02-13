require "net/http"
require "json"

module Smoke
  module TestHelpers
    include Shared::BrowserTestHelpers

    # Verify page content and missing translations (delegates to shared module).
    # Skips axe accessibility checks and I18n title validation for speed.
    def smoke_verify_page(title:, wait: Capybara.default_max_wait_time)
      verify_page_content(page, title: title, wait: wait)
    end

    # Poll until a condition is true, with timeout.
    # Used for waiting on real webhook processing (replaces @e2e.replay_webhooks).
    def poll_until(timeout: 120, interval: 3, message: "Timed out waiting")
      deadline = Time.now + timeout
      loop do
        result = yield
        return result if result
        raise message if Time.now > deadline
        sleep interval
      end
    end

    # Construct a full URL for a subdomain-based agency site.
    # e.g., site_url("sandbox", "/cbv/links/sandbox")
    #   => "https://sandbox-verify-demo.navapbc.cloud/cbv/links/sandbox"
    def site_url(subdomain, path = "/")
      base = URI.parse(SMOKE_BASE_URL)
      new_host = "#{subdomain}-#{base.host}"
      "#{base.scheme}://#{new_host}#{path}"
    end

    # Navigate to a different subdomain site, bypassing Capybara's app_host restriction.
    def visit_site(subdomain, path = "/")
      page.driver.browser.navigate.to(site_url(subdomain, path))
    end

    # Create a CBV flow invitation via the tokenization API.
    # Returns parsed JSON response with `tokenized_url`, `expiration_date`, etc.
    def create_invitation_via_api(params: {})
      uri = URI("#{SMOKE_BASE_URL}/api/v1/invitations")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer zkSbNq43AK86CEnOeUi3Xmhn46ORclKl"
      request["Content-Type"] = "application/json"
      request.body = params.to_json

      response = http.request(request)
      JSON.parse(response.body)
    end

    # Navigate through the entry page (consent + continue) to reach employer search.
    # Starts from whatever page is currently loaded.
    def complete_entry_page
      smoke_verify_page(title: "Let's verify your income")
      find('[data-cbv-entry-page-target="consentCheckbox"]').click
      click_button "Get started"
      smoke_verify_page(title: "Search for your employer or payroll provider", wait: 15)
    end

    # Navigate from payment details through summary (shared across flow specs).
    def complete_post_sync_pages(employer_name:)
      # Payment details
      smoke_verify_page(title: "Review your", wait: 60)
      fill_in "payroll_account[additional_information]",
        with: "Smoke test - #{Time.now.iso8601}"
      click_button "Continue"

      # Add job -> No
      smoke_verify_page(title: "Do you have another job to add?", wait: 10)
      find("label", text: "No, I don't have another job to add with this tool").click
      click_on "Continue"

      # Other jobs -> Yes
      smoke_verify_page(title: "Do you need to report other income from your work?", wait: 10)
      find("label", text: /Yes, I will report other income directly to/).click
      click_on "Continue"

      # Summary
      smoke_verify_page(title: "Review your income report", wait: 10)
      expect(page).to have_content(employer_name)
    end

    # Wait for synchronization to complete by polling until the page navigates away.
    def wait_for_sync_completion(timeout: 180)
      smoke_verify_page(title: "We're gathering your payment details from your employer", wait: 15)
      poll_until(timeout: timeout, interval: 5, message: "Webhooks did not arrive — synchronization timed out after #{timeout}s") do
        !page.current_url.include?("/synchronizations")
      end
    end

    # Connect via the Argyle modal using sandbox test credentials.
    def complete_argyle_modal
      argyle_container = find("div[id*='argyle-link-root']", visible: :all, wait: 30)

      page.within(argyle_container.shadow_root) do
        find('[name="username"]', wait: 15).fill_in(with: "test_1")
        find('[name="password"]').fill_in(with: "passgood")
        find('[data-hook="connect-button"]').click
        wait_for_idle
        find('[name="legacy_mfa_token"]', wait: 30).fill_in(with: "8081")
        wait_for_idle
        find('[data-hook="connect-button"]', wait: 30).click
      end

      # Wait for Argyle modal to disappear (connection successful)
      find_all("div[id*='argyle-link-root']", visible: :all, maximum: 0, minimum: nil, wait: 60)
    end

    # Connect via the Pinwheel modal using sandbox test credentials.
    def complete_pinwheel_modal
      pinwheel_modal = page.find("iframe.pinwheel-modal-show", wait: 30)

      page.within_frame(pinwheel_modal) do
        fill_in "Workday Organization ID", with: "company_good", wait: 20
        click_button "Continue"
        fill_in "Username", with: "user_good", wait: 20
        fill_in "Password", with: "pass_good"
        click_button "Continue"
      end

      # Wait for Pinwheel modal to disappear
      find_all("iframe.pinwheel-modal-show", visible: true, maximum: 0, minimum: nil, wait: 60)
    end

    # Fetch a PDF from the given URL using the browser's session cookies.
    # Returns the Net::HTTP response.
    def fetch_pdf_with_session(pdf_url)
      uri = URI(pdf_url)
      cookies = page.driver.browser.manage.all_cookies
      cookie_string = cookies.map { |c| "#{c[:name]}=#{c[:value]}" }.join("; ")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      request = Net::HTTP::Get.new(uri)
      request["Cookie"] = cookie_string
      http.request(request)
    end
  end
end
