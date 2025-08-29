module AutoTitleTestHelper
  def assert_title_contains_h1(response_body)
    parsed_body = Nokogiri::HTML(response_body)
    h1_elements = parsed_body.xpath("//body//h1")
    expect(h1_elements.length).to eq(1)

    title_elements = parsed_body.xpath("//head//title")
    expect(title_elements.length).to eq(1)

    title_contents = title_elements.first.text.split('|').first.strip
    h1_contents = h1_elements.first.text.strip
    expect(h1_contents).to include(title_contents), "H1 and title content differ: `#{h1_contents}` vs `#{title_contents}`"
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
