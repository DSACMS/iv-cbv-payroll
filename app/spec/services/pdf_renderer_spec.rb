require "rails_helper"

RSpec.describe PdfRenderer do
  let(:html) do
    <<~HTML
      <!DOCTYPE html><html lang="en"><head><title>Synthetic report</title></head><body>
      <h1>Synthetic report</h1><h2>Enrollment</h2>
      <p style="border-bottom: 1px solid black;"><span style="font-weight: bold;">Test School</span></p>
      <table><caption>Enrollment details</caption><thead><tr><th scope="col">School</th><th scope="col">Credits</th></tr></thead>
      <tbody><tr><th scope="row">Test School</th><td>3.5</td></tr></tbody></table>
      <ul><li>First item<span style="display: block; margin: 1em 0;">Additional detail</span></li></ul>
      </body></html>
    HTML
  end
  let(:content) { described_class.render(html) }
  let(:reader) { PDF::Reader.new(StringIO.new(content)) }
  let(:catalog) { reader.objects[reader.objects.trailer[:Root]] }

  def structure_tags(node)
    node = reader.objects[node] if node.is_a?(PDF::Reader::Reference)
    return node.flat_map { |child| structure_tags(child) } if node.is_a?(Array)
    return [] unless node.is_a?(Hash)

    [ node[:S], *structure_tags(node[:K]) ].compact
  end

  it "preserves report content and Chromium's accessibility metadata and structure" do
    expect(reader.pages.map(&:text).join(" ")).to include("Test School", "3.5", "First item", "Additional detail")
    expect(reader.info[:Title]).to eq("Synthetic report")
    expect(catalog[:Lang]).to eq("en")
    expect(reader.objects.deref_hash(catalog[:MarkInfo])[:Marked]).to be(true)
    expect(structure_tags(catalog[:StructTreeRoot])).to include(:H1, :H2, :Table, :TH, :TD, :L, :LI)
  end

  context "with stubbed browser output", :skip_pdf_accessibility_export do
    let(:original) { File.binread(Rails.root.join("spec/fixtures/files/document_upload.pdf")) }
    let(:browser) { instance_double(Grover, to_pdf: original) }

    before do
      allow(Grover).to receive(:new).and_return(browser)
    end

    it "returns Chromium's PDF unchanged" do
      expect(content).to eq(original)
    end

    it "converts report margins to millimeters" do
      described_class.render(html, margin: { top: 8, bottom: 8, left: 0, right: 0 })

      expect(Grover).to have_received(:new).with(
        html, margin: { top: "8mm", bottom: "8mm", left: "0mm", right: "0mm" }
      )
    end

    it "passes pagination footers to Chromium" do
      described_class.render(html, footer: "<span class='pageNumber'></span>")

      expect(Grover).to have_received(:new).with(
        html,
        margin: { top: "10mm", bottom: "10mm", left: "10mm", right: "10mm" },
        display_header_footer: true,
        header_template: "<span></span>",
        footer_template: "<span class='pageNumber'></span>"
      )
    end
  end
end
