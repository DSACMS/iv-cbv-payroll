require "rails_helper"

RSpec.describe EnrollmentTermTableComponent, type: :component do
  let(:term) { create(:nsc_enrollment_term, :full_time, school_certified_on: Date.new(2026, 9, 1)) }

  it "keeps the existing status rendering for review pages" do
    rendered = render_inline(described_class.new(nsc_enrollment_term: term))

    expect(rendered).to have_text("Full-time")
    expect(rendered).to have_no_text("as of")
    expect(rendered).to have_no_button("View enrollment history")
  end
end
