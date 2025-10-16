module E2e
  module TestHelpers
    # Verify that the page is correct: having the expected title, no missing
    # translations, and everything else.
    #
    # You can also use this method after clicking a "Submit" button to wait for
    # the next page to load. If the default wait time (2 seconds) isn't enough,
    # pass in a higher value (in seconds) in for `wait`.
    def verify_page(page, title:, wait: Capybara.default_max_wait_time, skip_axe_rules: [])
      wait_for_idle(page)

      expect(page).to have_content(title, wait: wait)

      # Verify page has no missing translations
      Capybara.using_wait_time(0) do
        missing_translations = page.all("span", class: "translation_missing")
        raise(<<~ERROR) if missing_translations.any?
          E2E test failed on #{page.current_url}:

          #{missing_translations.map { |el| el["title"] }}
        ERROR
      end

      # Check accessibility of every page with Axe matchers.
      #
      # This verifies against Axe's default ruleset, which is WCAG 2.1 Level A
      # & AA as well as an additional handful of best practices:
      #
      # https://github.com/dequelabs/axe-core/blob/master/doc/rule-descriptions.md
      expect(page).to be_axe_clean.skipping(skip_axe_rules)
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
  end
end
