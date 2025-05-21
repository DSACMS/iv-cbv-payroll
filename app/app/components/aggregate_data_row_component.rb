# frozen_string_literal: true

class AggregateDataRowComponent < ViewComponent::Base
  include ReportViewHelper


  def initialize(field, *values, highlight: false)
    @field = send(field, *values)
    @highlight = highlight
  end

  def accrued_gross_earnings(accrued_gross_earnings)
    {

      label: I18n.t("components.report.monthly_summary_table.accrued_gross_earnings"),
      value: format_money(accrued_gross_earnings)
    }
  end

  def total_gig_hours(total_gig_hours)
    {

      label: I18n.t("components.report.monthly_summary_table.total_gig_hours"),
      value: total_gig_hours
    }
  end

  def month(date)
    {

      label: I18n.t("components.report.monthly_summary_table.month"),
      value: format_parsed_date(date, :month_year)
    }
  end
end
