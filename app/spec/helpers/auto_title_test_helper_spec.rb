require "rails_helper"

RSpec.describe AutoTitleTestHelper do
  include described_class

  let(:page_heading) { "Search employers" }
  let(:additional_content) { "" }
  let(:response_body) do
    <<~HTML
      <html>
        <head><title>Search employers | Emmy</title></head>
        <body><h1>#{page_heading}</h1>#{additional_content}</body>
      </html>
    HTML
  end

  it "accepts a page heading matching the title" do
    expect { assert_title_contains_h1(response_body) }.not_to raise_error
  end

  context "with a heading inside a closed dialog" do
    let(:additional_content) { "<dialog><div><h1>Log in to payroll</h1></div></dialog>" }

    it "checks only the page heading" do
      expect { assert_title_contains_h1(response_body) }.not_to raise_error
    end
  end

  context "with a second page heading" do
    let(:additional_content) { "<h1>Another heading</h1>" }

    it "rejects duplicate headings" do
      expect { assert_title_contains_h1(response_body) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  context "with a heading inside an open dialog" do
    let(:additional_content) { "<dialog open><h1>Log in to payroll</h1></dialog>" }

    it "does not exclude the displayed heading" do
      expect { assert_title_contains_h1(response_body) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  context "with a page heading that differs from the title" do
    let(:page_heading) { "Unrelated heading" }

    it "rejects the mismatched title" do
      expect { assert_title_contains_h1(response_body) }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /H1 and title content differ/)
    end
  end
end
