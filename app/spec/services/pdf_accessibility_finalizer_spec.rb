require "rails_helper"

RSpec.describe PdfAccessibilityFinalizer do
  let(:html) do
    <<~HTML
      <!DOCTYPE html><html lang="en"><head><title>Synthetic report</title></head>
      <body style="background: #eef;">
      <h1>Synthetic report</h1><p>Meaningful report content</p>
      <ul><li><p><em>List detail</em></p></li></ul><p><strong>Emphasis</strong></p>
      <span aria-hidden="true">Do not silently hide untagged text</span>
      <svg aria-hidden="true" width="20" height="20"><path d="M0 0 L20 20" stroke="black"/></svg>
      </body></html>
    HTML
  end
  let(:original) { Grover.new(html).to_pdf }
  let(:content) { described_class.call(original) }
  let(:document) { HexaPDF::Document.new(io: StringIO.new(content)) }

  it "preserves text and page count" do
    before = PDF::Reader.new(StringIO.new(original))
    after = PDF::Reader.new(StringIO.new(content))

    expect(after.pages.map(&:text)).to eq(before.pages.map(&:text))
    expect(after.page_count).to eq(before.page_count)
  end

  it "adds document metadata and structure-based navigation" do
    expect(document.catalog[:Metadata].stream).to include("pdfuaid:part", "Synthetic report")
    expect(document.catalog[:ViewerPreferences][:DisplayDocTitle]).to be(true)
    expect(document.pages[0][:Tabs]).to eq(:S)
    expect(document.catalog[:Lang]).to eq("en")
  end

  it "maps emphasis roles and groups list content without breaking parent links" do
    role_map = document.catalog[:StructTreeRoot][:RoleMap]
    expect(role_map[:Em]).to eq(:Span)
    expect(role_map[:Strong]).to eq(:Span)
    item = document.each.find { |node| node.is_a?(HexaPDF::Dictionary) && node[:S] == :LI }
    expect(item[:K].map { |child| child[:S] }).to all(be_in([ :Lbl, :LBody ]))
    body = item[:K].find { |child| child[:S] == :LBody }
    expect(body[:P]).to eq(item)
    expect(body[:K].map { |child| child[:P] }).to all(eq(body))
  end

  it "marks drawings as artifacts without marking untagged text as decorative" do
    scopes = []
    artifacts = 0
    untagged_text = 0
    decoder = described_class::TextDecoder.new(document.pages[0].resources)
    HexaPDF::Content::Parser.parse(document.pages[0].contents) do |operator, operands|
      decoder.process(operator, operands)
      case operator
      when :BMC, :BDC
        scopes.push(operands.first)
        artifacts += 1 if operands.first == :Artifact
      when :EMC
        scopes.pop
      when :Tj, :TJ
        expect(scopes).not_to include(:Artifact) unless decoder.decode_text(operands.last).strip.empty?
        untagged_text += 1 if scopes.empty?
      end
    end

    expect(artifacts).to be_positive
    expect(untagged_text).to be_positive
  end

  context "with an untagged PDF" do
    let(:original) { File.binread(Rails.root.join("spec/fixtures/files/document_upload.pdf")) }

    it "rejects it instead of declaring an untagged document accessible" do
      expect { content }.to raise_error(ArgumentError, /requires tagged Chromium output/)
    end
  end

  context "with a known Chromium footer" do
    let(:html) { '<html lang="en"><head><title>Report</title></head><body><h1>Report</h1></body></html>' }
    let(:footer) { '<div style="font-size:10px">Page <span class="pageNumber"></span> of <span class="totalPages"></span></div>' }
    let(:original) { Grover.new(html, display_header_footer: true, header_template: "<span></span>", footer_template: footer).to_pdf }
    let(:content) { described_class.call(original, footer: footer) }

    it "marks the matching page footer as pagination without removing its visible text" do
      expect(document.pages[0].contents).to include("/Pagination", "/Footer")
      expect(PDF::Reader.new(StringIO.new(content)).pages.first.text).to include("Page 1 of 1")
    end

    context "with other untagged text on the page" do
      let(:html) { '<html lang="en"><head><title>Report</title></head><body><h1>Report</h1><span aria-hidden="true">Unclassified text</span></body></html>' }

      it "leaves the text unclassified rather than hiding it with the footer" do
        expect(document.pages[0].contents).not_to include("/Pagination")
        expect(PDF::Reader.new(StringIO.new(content)).pages.first.text).to include("Unclassified text")
      end
    end
  end
end
