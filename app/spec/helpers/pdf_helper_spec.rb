require "rails_helper"

RSpec.describe PdfHelper, type: :helper do
  it "embeds precompiled CSS as UTF-8 for Chromium's JSON transport" do
    allow(helper).to receive(:pdf_asset).with("application.css").and_return([ "/* café */ body { color: black; }".b, "text/css" ])

    stylesheet = helper.pdf_stylesheet

    expect(stylesheet.encoding).to eq(Encoding::UTF_8)
    expect(JSON.generate(html: stylesheet)).to include("café")
  end
end
