require "rails_helper"

RSpec.describe MemorableDateComponent, type: :component do
  before do
    stub_const("MemorableDateTestModel", Class.new do
      include ActiveModel::Model

      attr_accessor :date_of_birth
    end)
  end

  let(:object) { MemorableDateTestModel.new }
  let(:template) { ActionView::Base.empty }
  let(:form) { UswdsFormBuilder.new(:applicant, object, template, {}) }
  let(:result) do
    render_inline(
      described_class.new(
        form: form,
        attribute: :date_of_birth,
        legend: "Date of birth",
        hint: "Enter your date of birth"
      )
    )
  end

  it "describes valid controls with the hint only" do
    expect(result).to have_css(
      '.usa-memorable-date select[aria-describedby="date_of_birth_hint"]',
      count: 1
    )
    expect(result).to have_css(
      '.usa-memorable-date input[aria-describedby="date_of_birth_hint"]',
      count: 2
    )
    expect(result).to have_no_css('[aria-invalid="true"]')
    expect(result).to have_no_css(".usa-error-message")
  end

  context "with an invalid date" do
    before do
      object.errors.add(:date_of_birth, "is invalid")
    end

    it "connects the error to the date legend" do
      expect(result).to have_css(
        "legend#applicant_date_of_birth_legend",
        text: "Date of birth"
      )
      expect(result).to have_css(
        "#applicant_date_of_birth_error.usa-error-message" \
        '[data-error-label-id="applicant_date_of_birth_legend"]',
        text: "is invalid"
      )
    end

    it "associates the fieldset with the generated error and hint" do
      expect(result).to have_css(
        'fieldset[aria-describedby="' \
        'applicant_date_of_birth_error date_of_birth_hint"]'
      )
    end

    it "associates the month select with the error and hint" do
      expect(result).to have_css(
        'select#applicant_date_of_birth_month[aria-invalid="true"]' \
        '[aria-describedby="applicant_date_of_birth_error date_of_birth_hint"]'
      )
    end

    it "associates the day and year inputs with the error and hint" do
      expect(result).to have_css(
        '.usa-memorable-date input[aria-invalid="true"]' \
        '[aria-describedby="applicant_date_of_birth_error date_of_birth_hint"]',
        count: 2
      )
    end

    it "does not reference the old unprefixed error ID" do
      expect(result).to have_no_css('[aria-describedby~="date_of_birth_error"]')
    end
  end
end
