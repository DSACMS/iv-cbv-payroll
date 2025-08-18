# frozen_string_literal: true

class MemorableDateComponentPreview < ApplicationPreview
  def default
    render(MemorableDateComponent.new(
      form: UswdsFormBuilder.new(:applicant,
        CbvApplicant::Sandbox.new(date_of_birth: nil),
        view_context,
        {}
      ),
      attribute: :date_of_birth,
      legend: "Date of Birth",
      hint: "For example: January 19 2000"
    ))
  end

  def with_existing_date
    render(MemorableDateComponent.new(
      form: UswdsFormBuilder.new(:applicant,
        CbvApplicant::Sandbox.new(date_of_birth: Date.new(1985, 3, 15)),
        view_context,
        {}
      ),
      attribute: :date_of_birth,
      legend: "Date of Birth",
      hint: "For example: January 19 2000"
    ))
  end

  def with_errors
    applicant = CbvApplicant::Sandbox.new(date_of_birth: nil)
    applicant.errors.add(:date_of_birth, I18n.t("cbv.applicant_informations.sandbox.fields.date_of_birth.blank"))

    render(MemorableDateComponent.new(
      form: UswdsFormBuilder.new(:applicant, applicant, view_context, {}),
      attribute: :date_of_birth,
      legend: "Date of Birth",
      hint: "For example: January 19 2000"
    ))
  end

  def without_hint
    render(MemorableDateComponent.new(
      form: UswdsFormBuilder.new(:applicant,
        CbvApplicant::Sandbox.new(date_of_birth: nil),
        view_context,
        {}
      ),
      attribute: :date_of_birth,
      legend: "Date of Birth"
    ))
  end
end
