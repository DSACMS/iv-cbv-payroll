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
end
