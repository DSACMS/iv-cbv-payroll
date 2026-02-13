module Shared
  module BrowserTestHelpers
    # Wait for browser idle state using requestIdleCallback.
    # Ensures the page has finished rendering and processing before assertions.
    def wait_for_idle(page = self.page)
      page.driver.browser.execute_async_script(<<~JS)
        const callback = arguments[arguments.length - 1];
        window.requestIdleCallback(callback, { timeout: 2000 });
      JS
    end

    # Core page verification: content present + no missing translations.
    # This is the shared foundation used by both E2e::TestHelpers#verify_page
    # and Smoke::TestHelpers#smoke_verify_page.
    def verify_page_content(page, title:, wait: Capybara.default_max_wait_time)
      wait_for_idle(page)

      expect(page).to have_content(title, wait: wait)

      # Verify page has no missing translations
      Capybara.using_wait_time(0) do
        missing_translations = page.all("span", class: "translation_missing")
        raise(<<~ERROR) if missing_translations.any?
          Test failed on #{page.current_url}:

          #{missing_translations.map { |el| el["title"] }}
        ERROR
      end
    end
  end
end
