require "rails_helper"

RSpec.describe EnrollmentTermTableComponent, type: :component do
  let(:term) { create(:nsc_enrollment_term, :full_time, school_certified_on: Date.new(2026, 9, 1)) }

  it "keeps the existing status rendering for review pages" do
    rendered = render_inline(described_class.new(nsc_enrollment_term: term))

    expect(rendered).to have_text("Full-time")
    expect(rendered).to have_no_text("as of")
    expect(rendered).to have_no_button("View enrollment history")
  end

  context "with an NSC withdrawn record" do
    let(:term) { create(:nsc_enrollment_term, enrollment_status: :unknown, nsc_withdrawn: true) }

    it "keeps the normalized status on review pages" do
      rendered = render_inline(described_class.new(nsc_enrollment_term: term))

      expect(rendered).to have_text(I18n.t("shared.not_applicable"))
      expect(rendered).to have_no_text("Withdrawn")
    end
  end
end
