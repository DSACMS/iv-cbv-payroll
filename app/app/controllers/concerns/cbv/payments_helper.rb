module Cbv::PaymentsHelper
  def set_payments(account_id = nil)
    payments = account_id.nil? ? fetch_payroll : fetch_payroll_for_account_id(account_id)

    @payments = parse_payments(payments)
  end

  def fetch_payroll
    end_user_account_ids = pinwheel.fetch_accounts(end_user_id: @cbv_flow.pinwheel_end_user_id)["data"].map { |account| account["id"] }

    end_user_account_ids.map do |account_id|
      fetch_payroll_for_account_id account_id
    end.flatten
  end

  def fetch_payroll_for_account_id(account_id)
    pinwheel.fetch_paystubs(account_id: account_id, from_pay_date: 90.days.ago.strftime("%Y-%m-%d"))["data"]
  end

  def parse_payments(payments)
    payments.map do |payment|
      earnings_with_hours = payment["earnings"].max_by { |e| e["hours"] || 0.0 }

      {
        employer: payment["employer_name"],
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

  def summarize_by_employer(payments)
    payments.each_with_object({}) do |payment, hash|
      account_id = payment[:account_id]
      hash[account_id] ||= {
        employer_name: payment[:employer],
        total: 0,
        payments: []
      }
      hash[account_id][:total] += payment[:net_pay_amount]
      hash[account_id][:payments] << payment
    end
  end
end
