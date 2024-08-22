# frozen_string_literal: true

class PinwheelDataPointComponent < ViewComponent::Base
  include ViewHelper

  def initialize(field, *values)
    @field = send(field, *values)
  end

  def pay_period(start_date, end_date)
    {
      label: I18n.t("cbv.payment_details.show.pay_period"),
      value: "#{format_date(start_date)} to #{format_date(end_date)}"
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

  def deduction(category, amount)
    {
      label: I18n.t("cbv.payment_details.show.deductions", category: category&.humanize),
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
      value: format_view_datetime(start_date)
    }
  end

  def employment_end_date(end_date)
    {
      label: I18n.t("cbv.payment_details.show.employment_end_date"),
      value: end_date ? format_date(end_date) : I18n.t("shared.not_applicable")
    }
  end

  def employment_status(status)
    {
      label: I18n.t("cbv.payment_details.show.employment_status"),
      value: status&.humanize
    }
  end

  def pay_frequency(frequency)
    {
      label: I18n.t("cbv.payment_details.show.pay_frequency"),
      value: frequency
    }
  end

  def hourly_rate(amount, unit)
    {
      label: I18n.t("cbv.payment_details.show.hourly_rate"),
      value: "#{format_money(amount)} #{unit}"
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
end
