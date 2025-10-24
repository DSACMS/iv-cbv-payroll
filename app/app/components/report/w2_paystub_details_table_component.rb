# frozen_string_literal: true

class Report::W2PaystubDetailsTableComponent < ViewComponent::Base
  include ReportViewHelper

  def initialize(
    paystub,
    income: nil,
    employer_name: nil,
    is_caseworker: false,
    is_responsive: true,
    show_hours_breakdown: true,
    show_gross_pay_ytd: true,
    show_pay_frequency: true,
    is_personalized: false,
    pay_frequency_text: nil
  )
    @paystub = paystub
    @income = income
    @employer_name = employer_name
    @is_caseworker = is_caseworker
    @is_responsive = is_responsive
    @show_hours_breakdown = show_hours_breakdown
    @show_gross_pay_ytd = show_gross_pay_ytd
    @show_pay_frequency = show_pay_frequency
    @is_personalized = is_personalized
    @custom_pay_frequency_text = pay_frequency_text
  end

  private

  def details_header
    if @is_personalized
      t("components.report.w2_paystub_details_table.your_details")
    else
      t("components.report.w2_paystub_details_table.details")
    end
  end

  def pay_frequency_text
    return @custom_pay_frequency_text if @custom_pay_frequency_text

    if @income&.pay_frequency
      @income.pay_frequency&.humanize
    else
      t("components.report.w2_paystub_details_table.frequency_unknown")
    end
  end

  def show_gross_pay_ytd?
    case @show_gross_pay_ytd
    when :if_positive
      @paystub.gross_pay_ytd.to_f > 0
    when false
      false
    else
      true
    end
  end

  def show_pay_frequency?
    @show_pay_frequency
  end

  def show_hours_breakdown?
    @show_hours_breakdown
  end
end
