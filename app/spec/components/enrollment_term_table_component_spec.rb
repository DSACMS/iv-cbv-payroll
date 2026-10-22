require "rails_helper"

RSpec.describe EnrollmentTermTableComponent, type: :component do
  let(:term) { create(:nsc_enrollment_term, enrollment_status: "unknown", nsc_withdrawn: true) }

  it "continues to display N/A for a withdrawn NSC enrollment" do
    rendered = render_inline(described_class.new(nsc_enrollment_term: term))

    expect(rendered).to have_text(I18n.t("shared.not_applicable"))
    expect(rendered).to have_no_text("Withdrawn")
  end
end
