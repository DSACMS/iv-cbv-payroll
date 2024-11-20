# frozen_string_literal: true

class PinwheelDataPointComponent < ViewComponent::Base
  include ViewHelper

  def initialize(field, *values, highlight: false)
    @field = send(field, *values)
    @highlight = highlight
  end

  def pay_period(start_date, end_date)
    {
      label: I18n.t("cbv.payment_details.show.pay_period"),
      value: I18n.t("cbv.payment_details.show.pay_period_value", start_date: format_date(start_date), end_date: format_date(end_date))
    }
  end

  def pay_period_with_frequency(start_date, end_date, pay_frequency)
    translated_pay_frequency = translate_pinwheel_value("payment_frequencies", pay_frequency)
    {
      label: I18n.t("cbv.summaries.show.pdf.caseworker.pay_period", pay_frequency: translated_pay_frequency),
      value: I18n.t("cbv.payment_details.show.pay_period_value", start_date: format_date(start_date), end_date: format_date(end_date))
    }
  end

  def pay_gross(gross_pay_amount)
    {
      label: I18n.t("cbv.payment_details.show.pay_gross"),
      value: format_money(gross_pay_amount)
    }
  end

  def net_pay_amount(net_pay_amount)
    {
      label: I18n.t("cbv.payment_details.show.pay_net"),
      value: format_money(net_pay_amount)
    }
  end

  def number_of_hours_worked(hours)
    {
      label: I18n.t("cbv.payment_details.show.number_of_hours_worked"),
      value: I18n.t("cbv.payment_details.show.payment_hours", amount: hours)
    }
  end

  def earnings_entry(category, hours)
    translated_category_name = translate_pinwheel_value("earnings_category", category)

    {
      label: I18n.t("cbv.payment_details.show.hours_paid", category: translated_category_name),
      value: I18n.t("cbv.payment_details.show.hours", count: hours)
    }
  end

  def deduction(category, amount)
    translated_deduction_category = translate_pinwheel_value("deductions", category)
    {
      label: I18n.t("cbv.payment_details.show.deductions", category: translated_deduction_category&.humanize),
      value: format_money(amount)
    }
  end

  def pay_gross_ytd(gross_pay_ytd)
    {
      label: I18n.t("cbv.payment_details.show.pay_gross_ytd"),
      value: format_money(gross_pay_ytd)
    }
  end

  def employment_start_date(start_date)
    {
      label: I18n.t("cbv.payment_details.show.employment_start_date"),
      value: format_date(start_date)
    }
  end

  def employment_end_date(end_date)
    {
      label: I18n.t("cbv.payment_details.show.employment_end_date"),
      value: end_date ? format_date(end_date) : I18n.t("shared.not_applicable")
    }
  end

  def employment_status(status)
    translated_status = translate_pinwheel_value("employment_statuses", status)
    {
      label: I18n.t("cbv.payment_details.show.employment_status"),
      value: translated_status&.humanize
    }
  end

  def pay_frequency(frequency)
    translated_pay_frequency = translate_pinwheel_value("payment_frequencies", frequency)
    {
      label: I18n.t("cbv.payment_details.show.pay_frequency"),
      value: translated_pay_frequency
    }
  end

  def hourly_rate(amount, unit)
    translated_unit = translate_pinwheel_value("payment_frequencies", unit)
    {
      label: I18n.t("cbv.payment_details.show.hourly_rate"),
      value: "#{format_money(amount)} #{translated_unit}"
    }
  end

  def employer_phone(phone_number)
    {
      label: I18n.t("cbv.summaries.show.phone_number"),
      value: number_to_phone(phone_number)
    }
  end

  def employer_address(address)
    {
      label: I18n.t("cbv.summaries.show.pdf.client.address"),
      value: address
    }
  end

  def client_full_name(full_name)
    {
      label: I18n.t("cbv.summaries.show.pdf.caseworker.client_full_name"),
      value: full_name
    }
  end
end
