module Cbv::PaymentsHelper
  def summarize_by_employer(payments)
    payments.each_with_object({}) do |payment, hash|
      account_id = payment[:account_id]
      hash[account_id] ||= {
        employer_name: payment[:employer],
        total: 0,
        payments: []
      }
      hash[account_id][:total] += payment[:amount]
      hash[account_id][:payments] << payment
    end
  end

  def parse_payments(payments)
    payments.map do |payment|
      {
        employer: payment["employer_name"],
        amount: payment["net_pay_amount"].to_i,
        start: payment["pay_period_start"],
        end: payment["pay_period_end"],
        hours: payment["earnings"][0]["hours"],
        rate: payment["earnings"][0]["rate"],
        gross_pay_amount: payment["gross_pay_amount"].to_i,
        net_pay_amount: payment["net_pay_amount"].to_i,
        gross_pay_ytd: payment["gross_pay_ytd"].to_i,
        pay_date: payment["pay_date"],
        deductions: payment["deductions"].map { |deduction| { category: deduction["category"], amount: deduction["amount"] } },
        account_id: payment["account_id"]
      }
    end
  end
end
