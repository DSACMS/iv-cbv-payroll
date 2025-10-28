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
  # @param show_earnings_items [Boolean] If true, shows earnings items in a separate table at the bottom
  def initialize(
    paystub,
    income: nil,
    is_caseworker: false,
    is_responsive: true,
    is_personalized: false,
    show_hours_breakdown: true,
    show_gross_pay_ytd: true,
    show_pay_frequency: true,
    show_earnings_items: false
  )
    @paystub = paystub
    @income = income
    @is_caseworker = is_caseworker
    @is_responsive = is_responsive
    @is_personalized = is_personalized
    @show_hours_breakdown = show_hours_breakdown
    @show_gross_pay_ytd = show_gross_pay_ytd
    @show_pay_frequency = show_pay_frequency
    @show_earnings_items = show_earnings_items
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

  def show_earnings_items?
    @show_earnings_items && @paystub.earnings.present?
  end

  def earnings_sort_order(earnings)
    category_order = %w[
      base
      overtime
      pto
      commission
      tips
      bonus
      benefits
      other
      disability
      stock
    ].freeze

    # Convert to a hash for O(1) lookups during sort
    category_index = category_order.each_with_index.to_h.freeze
    default_index = category_order.length + 1

    earnings.sort_by.with_index do |earning, index|
      # First, sort by category order. If equal, sort by original index
      [ category_index[earning.category&.downcase] || default_index, index ]
    end
  end

  def earning_label(earning)
    "#{t("components.report.w2_paystub_details_table.gross_pay_item_prefix")} #{earning.name}"
  end

  def paystub_heading
    "#{t("components.report.w2_paystub_details_table.paystub_heading_prefix")} #{format_date(@paystub.pay_date)}"
  end
end
