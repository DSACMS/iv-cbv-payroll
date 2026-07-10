module E2e
  module TestHelpers
    # Tracks paths already axe-checked in this process, for E2E_AXE_MODE=sample.
    AXED_PATHS = Set.new

    # Verify that the page is correct: having the expected title, no missing
    # translations, and everything else.
    #
    # You can also use this method after clicking a "Submit" button to wait for
    # the next page to load. If the default wait time (2 seconds) isn't enough,
    # pass in a higher value (in seconds) in for `wait`.
    def verify_page(page, title:, wait: Capybara.default_max_wait_time, skip_axe_rules: [])
      wait_for_idle(page)

      retry_on_transient_selenium_page_error do
        expect(page).to have_content(title, wait: wait)
      end

      # Verify page has no missing translations
      Capybara.using_wait_time(0) do
        missing_translations = page.all("span", class: "translation_missing")
        raise(<<~ERROR) if missing_translations.any?
          E2E test failed on #{page.current_url}:

          #{missing_translations.map { |el| el["title"] }}
        ERROR
      end

      # Infer flow from URL
      current_path = URI.parse(page.current_url).path
      if current_path&.start_with?("/activities") || current_path&.start_with?("/households") || current_path&.start_with?("/launcher")
        pilot_name ||= I18n.t("shared.pilot_name_hr1_full")
      elsif current_path&.include?("/cbv/")
        pilot_name ||= I18n.t("shared.pilot_name")
      else
        pilot_name ||= I18n.t("shared.pilot_name")
      end

      # Verify page has a <title> tag that isn't just the default
      expect(page.title).to end_with("| #{pilot_name}")
      expect(page.title).not_to eq("| #{pilot_name}")

      run_axe_check(page, current_path, skip_axe_rules)
    end

    # Check accessibility with Axe matchers.
    #
    # E2E_AXE_MODE controls coverage:
    # - "sample" (default): one check per unique path across the whole run
    # - "full": check every time verify_page is called (used in CI)
    # - "off": skip entirely (use for fast local iteration)
    #
    # Axe's default ruleset covers WCAG 2.1 Level A & AA plus best practices:
    # https://github.com/dequelabs/axe-core/blob/master/doc/rule-descriptions.md
    def run_axe_check(page, current_path, skip_axe_rules)
      case ENV.fetch("E2E_AXE_MODE", "sample")
      when "off"
        nil
      when "full"
        expect(page).to be_axe_clean.skipping(skip_axe_rules)
      else
        expect(page).to be_axe_clean.skipping(skip_axe_rules) if AXED_PATHS.add?(current_path)
      end
    end

    # This method needs to be included in E2E tests using Pinwheel to make sure
    # that the `end_user_id` value matches between when the cassette was
    # recorded and when the test is run later. The `cassette_name` is hashed to
    # deterministically generate a UUID.
    #
    # Call this method in your E2E test after the /entry page, like so:
    #
    #   update_cbv_flow_with_deterministic_end_user_id_for_pinwheel(@e2e.cassette_name)
    #
    def update_cbv_flow_with_deterministic_end_user_id_for_pinwheel(cassette_name)
      cassette_name_as_integer = Digest::MD5.hexdigest(cassette_name).to_i(16)
      CbvFlow.last.update(end_user_id: Random.new(cassette_name_as_integer).uuid)
    end

    def wait_for_idle(page)
      page.driver.browser.execute_async_script(<<~JS)
        const callback = arguments[arguments.length - 1];
        window.requestIdleCallback(callback, { timeout: 2000 });
      JS
    end

    def retry_on_transient_selenium_page_error(max_attempts: 3)
      attempts = 0

      begin
        attempts += 1
        yield
      rescue Selenium::WebDriver::Error::UnknownError => e
        raise unless e.message.include?("Node with given id does not belong to the document")
        raise if attempts >= max_attempts

        sleep 0.1
        retry
      end
    end
  end
end
