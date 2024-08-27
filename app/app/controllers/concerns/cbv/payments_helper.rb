module Cbv::PaymentsHelper
  def set_payments(account_id = nil)
    invitation = @cbv_flow.cbv_flow_invitation
    to_pay_date = invitation.snap_application_date
    from_pay_date = invitation.paystubs_query_begins_at
    payments = account_id.nil? ? fetch_payroll(from_pay_date.strftime("%Y-%m-%d"), to_pay_date.strftime("%Y-%m-%d")) : fetch_payroll_for_account_id(account_id, from_pay_date.strftime("%Y-%m-%d"), to_pay_date.strftime("%Y-%m-%d"))
    @payments_ending_at = to_pay_date.strftime("%B %d, %Y")
    @payments_beginning_at = from_pay_date.strftime("%B %d, %Y")
    @payments = parse_payments(payments)
  end

  def fetch_payroll(from_pay_date, to_pay_date)
    fetch_known_end_user_account_ids.map do |account_id|
      fetch_payroll_for_account_id(account_id, from_pay_date, to_pay_date)
    end.flatten
  end

  def fetch_payroll_for_account_id(account_id, from_pay_date, to_pay_date)
    pinwheel.fetch_paystubs(account_id: account_id, from_pay_date: from_pay_date, to_pay_date: to_pay_date)["data"]
  end

  def parse_payments(payments)
    payments.map do |payment|
      earnings_with_hours = payment["earnings"].max_by { |e| e["hours"] || 0.0 }

      {
        start: payment["pay_period_start"],
        end: payment["pay_period_end"],
        hours: earnings_with_hours["hours"],
        rate: earnings_with_hours["rate"],
        gross_pay_amount: payment["gross_pay_amount"].to_i,
        net_pay_amount: payment["net_pay_amount"].to_i,
        gross_pay_ytd: payment["gross_pay_ytd"].to_i,
        pay_date: payment["pay_date"],
        deductions: payment["deductions"].map { |deduction| { category: deduction["category"], amount: deduction["amount"] } },
        account_id: payment["account_id"]
      }
    end
  end

  def fetch_known_end_user_account_ids
    pinwheel_account_ids = pinwheel.fetch_accounts(end_user_id: @cbv_flow.pinwheel_end_user_id)["data"].map { |account| account["id"] }

    PinwheelAccount.where(pinwheel_account_id: pinwheel_account_ids).map(&:pinwheel_account_id)
  end
end
