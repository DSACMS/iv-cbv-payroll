module AutoTitleTestHelper
  H1_REGEX = /<h1>(.*?)<\/h1>/im
  TITLE_REGEX = /<title>(.*?)<\/title>/im
  INTERPOLATION_REGEX = /%\{.*?}/

  def assert_title_contains_h1(response_body)
    # There are instances where the top-level h1 can vary from the title. For example- if the page's leading header contains html markup
    h1_content = ActionController::Base.helpers.strip_tags(decode_html_entities(extract_content(response_body, H1_REGEX)))
    expect(h1_content).to be_present, "H1 is missing"

    title_content = decode_html_entities(extract_content(response_body, TITLE_REGEX))
    expect(title_content).to be_present, "Title is missing"

    cleaned_title = remove_interpolation_placeholders(title_content)
    main_title = cleaned_title.split('|').first.strip

    expect(h1_content).to include(main_title), "H1 and title content differ: `#{h1_content}` vs `#{main_title}`"
  end

  private

  def extract_content(html, regex)
    match = html.match(regex)
    match ? match[1].strip : nil
  end

  def remove_interpolation_placeholders(text)
    text.gsub(INTERPOLATION_REGEX, '').squeeze(' ').strip
  end

  def decode_html_entities(text)
    return unless text
    CGI.unescapeHTML(text)
  end
end

RSpec.configure do |config|
  config.include AutoTitleTestHelper, type: :controller

  config.after(:each, type: :controller) do
    if should_check_title?(request, response)
      assert_title_contains_h1(response.body)
    end
  end

  def should_check_title?(request, response)
    (request.get? || request.params[:action] == 'show') &&
      !%w[new create].include?(request.params[:action]) &&
      response.body.present? &&
      response.status == 200 &&
      response.content_type =~ /html/
  end
end
