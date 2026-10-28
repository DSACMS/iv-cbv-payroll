require "rails_helper"

RSpec.describe PdfRenderer do
  let(:html) do
    <<~HTML
      <!DOCTYPE html><html lang="en"><head><title>Synthetic report</title></head><body>
      <h1>Synthetic report</h1><h2>Enrollment</h2>
      <p><strong>Test School</strong></p><span aria-hidden="true">|</span>
      <table><caption>Enrollment details</caption><thead><tr><th scope="col">School</th><th scope="col">Credits</th></tr></thead>
      <tbody><tr><th scope="row">Test School</th><td>3.5</td></tr></tbody></table>
      <ul><li>First item<p>Additional detail</p></li></ul>
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


  it "preserves report content and supplies accessibility metadata and structure" do
    expect(reader.pages.map(&:text).join(" ")).to include("Test School", "3.5", "First item", "Additional detail")
    expect(reader.info[:Title]).to eq("Synthetic report")
    expect(catalog[:Lang]).to eq("en")
    expect(reader.objects.deref_hash(catalog[:MarkInfo])[:Marked]).to be(true)
    expect(reader.objects.deref_hash(catalog[:ViewerPreferences])[:DisplayDocTitle]).to be(true)
    expect(structure_tags(catalog[:StructTreeRoot])).to include(:H1, :H2, :Table, :TH, :TD, :L, :LI, :LBody)
    expect(reader.objects[catalog[:Metadata]].data).to include("<pdfuaid:part>1</pdfuaid:part>")
  end

  it "refuses to claim compliance for untagged input" do
    allow(Grover).to receive(:new).and_return(instance_double(Grover, to_pdf: File.binread(Rails.root.join("spec/fixtures/files/document_upload.pdf"))))
    expect { content }.to raise_error(/PDF accessibility finalization failed/)
  end
end
