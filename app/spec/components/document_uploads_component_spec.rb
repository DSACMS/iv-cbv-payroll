# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentUploadsComponent, type: :component do
  before do
    allow_any_instance_of(described_class).to receive(:asset_path).and_return("/assets/sprite.svg")
  end

  it "renders the uploaded documents heading, icon, and filenames" do
    result = render_inline(
      described_class.new(documents: [
        { filename: "verification.pdf" },
        { filename: "paystub.jpg" }
      ])
    )

    expect(result).to have_text("Previously uploaded documents (2)")
    expect(result).to have_text("verification.pdf")
    expect(result).to have_text("paystub.jpg")
    expect(result).to have_element(:use, href: /.svg#file_present/)
    expect(result).not_to have_text("Remove file")
  end

  it "renders remove links when enabled" do
    result = render_inline(
      described_class.new(
        documents: [ { filename: "verification.pdf", remove_path: "/documents/1" } ],
        show_remove_file: true
      )
    )

    expect(result).to have_link("Remove file", href: "/documents/1")
    expect(result.to_html).to include('data-turbo-method="delete"')
  end
end
