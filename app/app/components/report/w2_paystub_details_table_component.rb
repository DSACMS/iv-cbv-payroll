# frozen_string_literal: true

class Report::W2PaystubDetailsTableComponent < ViewComponent::Base
  include ReportViewHelper

  # @param paystub [Aggregators::ResponseObjects::Paystub] The paystub data to display
  # @param income [Aggregators::ResponseObjects::Income, nil] Income object containing pay frequency info
  # @param is_caseworker [Boolean] If true, highlights certain fields for caseworker view
  # @param is_responsive [Boolean] If true, table adapts to mobile screens.  If false, does not (e.g. PDF)
  # @param is_personalized [Boolean] If true, uses "Your details" header; if false, uses "Details"
  # @param show_hours_breakdown [Boolean] If true, shows hours by earning category (Regular, Commission, etc.)
  # @param show_gross_pay_ytd [Boolean] If true, shows gross pay year-to-date (only if value > 0)
  # @param show_pay_frequency [Boolean] If true, shows pay period with frequency
  def initialize(
    paystub,
    income: nil,
    is_caseworker: false,
    is_responsive: true,
    is_personalized: false,
    show_hours_breakdown: true,
    show_gross_pay_ytd: true,
    show_pay_frequency: true
  )
    @paystub = paystub
    @income = income
    @is_caseworker = is_caseworker
    @is_responsive = is_responsive
    @is_personalized = is_personalized
    @show_hours_breakdown = show_hours_breakdown
    @show_gross_pay_ytd = show_gross_pay_ytd
    @show_pay_frequency = show_pay_frequency
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
    if @income&.pay_frequency
      @income.pay_frequency&.humanize
    else
      t("components.report.w2_paystub_details_table.frequency_unknown")
    end
  end

  def show_gross_pay_ytd?
    @show_gross_pay_ytd && @paystub.gross_pay_ytd.to_f > 0
  end

  def show_pay_frequency?
    @show_pay_frequency
  end

  def show_hours_breakdown?
    @show_hours_breakdown
  end
end
