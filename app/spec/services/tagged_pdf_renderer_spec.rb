require "rails_helper"
require "hexapdf"
require "stringio"

RSpec.describe TaggedPdfRenderer, type: :service do
  let(:html) do
    <<~HTML
      <!doctype html>
      <html lang="en">
        <body>
          <table>
            <thead>
              <tr><th scope="col">Heading</th></tr>
            </thead>
            <tbody>
              <tr><th scope="row">Row heading</th><td data-label="Heading">Cell contents</td></tr>
            </tbody>
          </table>
        </body>
      </html>
    HTML
  end

  it "removes responsive table labels before sending HTML to Chromium" do
    grover = instance_double(Grover, to_pdf: pdf_fixture)
    rendered_html = nil
    allow(Grover).to receive(:new) do |html, **|
      rendered_html = html
      grover
    end

    described_class.render(html)

    document = Nokogiri::HTML(rendered_html)

    expect(document.at_css("td").attributes).not_to include("data-label")
    expect(document.at_css("td").text).to eq("Cell contents")
    expect(document.at_css("th[scope='col']").text).to eq("Heading")
    expect(document.at_css("th[scope='row']").text).to eq("Row heading")
  end

  it "normalizes Chromium's generic text tags without changing the PDF byte offsets" do
    grover = instance_double(Grover, to_pdf: pdf_fixture.gsub("/S /Table", "/S /NonStruct /S /Table"))
    allow(Grover).to receive(:new).and_return(grover)

    pdf = described_class.render("<html><body>Content</body></html>")

    expect(pdf).to include("/S /Span     ")
    expect(pdf).not_to include("/S /NonStruct")
    expect(pdf.bytesize).to eq(grover.to_pdf.bytesize)
    expect(pdf).to include("/S /Table")
  end

  it "adds the application author and subject to the PDF document properties" do
    grover = instance_double(Grover, to_pdf: pdf_fixture)
    allow(Grover).to receive(:new).and_return(grover)

    pdf = described_class.render("<html><body>Content</body></html>")
    document = HexaPDF::Document.new(io: StringIO.new(pdf))

    expect(document.trailer.info[:Author]).to eq("Emmy application 1.0")
    expect(document.trailer.info[:Subject]).to eq("Emmy Community Engagement and/or Income submission")
  end

  def pdf_fixture
    document = HexaPDF::Document.new
    document.pages.add
    output = StringIO.new
    document.write(output)
    output.string
  end
end
