require "rails_helper"

RSpec.describe EnrollmentTermTableComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(nsc_enrollment_term: term)) }

  let(:term) do
    NscEnrollmentTerm.new(
      enrollment_status: status, school_name: "Test College", first_name: "Test", last_name: "Student",
      term_begin: Date.new(2024, 1, 1), term_end: Date.new(2024, 6, 30)
    )
  end

  context "with a leave of absence" do
    let(:status) { :leave_of_absence }

    it "displays leave of absence" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
    end
  end

  context "with a withdrawal" do
    let(:status) { :withdrawn }

    it "displays withdrawn" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.withdrawn"))
    end
  end

  context "with graduation" do
    let(:status) { :graduated }

    it "displays graduated" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.graduated"))
    end
  end

  context "with a deceased student" do
    let(:status) { :deceased }

    it "displays deceased" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.deceased"))
    end
  end

  context "when the school has not released the enrollment status" do
    let(:status) { :enrolled }

    it "describes the meaning of the raw Y code" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
    end
  end
end
