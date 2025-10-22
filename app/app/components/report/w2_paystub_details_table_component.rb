# frozen_string_literal: true

class Report::W2PaystubDetailsTableComponent < ViewComponent::Base
  include ReportViewHelper

  def initialize(paystub, income: nil, employer_name: nil, is_caseworker: false, is_responsive: true, is_pdf: false)
    @paystub = paystub
    @income = income
    @employer_name = employer_name
    @is_caseworker = is_caseworker
    @is_responsive = is_responsive
    @is_pdf = is_pdf
  end

  private

  def pay_frequency_text
    if @income&.pay_frequency
      @income.pay_frequency&.humanize
    else
      t("cbv.payment_details.show.frequency_unknown")
    end
  end

  def translation_scope
    @is_pdf ? ".pdf.shared" : "cbv.payment_details.show"
  end
end
