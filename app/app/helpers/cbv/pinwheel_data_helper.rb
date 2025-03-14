module Cbv::PinwheelDataHelper
  include ViewHelper

  def set_payments(account_id = nil)
    applicant = @cbv_flow.cbv_applicant
    to_pay_date = applicant.created_at
    from_pay_date = applicant.snap_application_date
    @payments =
      if account_id.nil?
        fetch_paystubs(from_pay_date, to_pay_date)
      else
        fetch_paystubs_for_account_id(account_id, from_pay_date, to_pay_date)
      end
    @payments_ending_at = format_date(to_pay_date)
    @payments_beginning_at = format_date(from_pay_date)
  end

  def set_employments
    @employments = @cbv_flow.payroll_accounts.map do |pinwheel_account|
      next unless pinwheel_account.job_succeeded?("employment")

      pinwheel.fetch_employment(account_id: pinwheel_account.pinwheel_account_id)
    end.compact
  end

  def set_incomes
    @incomes = @cbv_flow.payroll_accounts.map do |pinwheel_account|
      next unless pinwheel_account.job_succeeded?("income")

      pinwheel.fetch_income(account_id: pinwheel_account.pinwheel_account_id)
    end.compact
  end

  def set_identities
    @identities = @cbv_flow.payroll_accounts.map do |pinwheel_account|
      next unless pinwheel_account.job_succeeded?("identity")

      pinwheel.fetch_identity(account_id: pinwheel_account.pinwheel_account_id)
    end.compact
  end

  def hours_by_earning_category(earnings)
  end

  def payments_grouped_by_employer
    summarize_by_employer(@payments, @employments, @incomes, @identities, @cbv_flow.payroll_accounts)
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment.gross_pay_amount }
  end

  def summarize_by_employer(payments, employments, incomes, identities, pinwheel_accounts)
    pinwheel_accounts
      .each_with_object({}) do |pinwheel_account, hash|
        account_id = pinwheel_account.pinwheel_account_id
        has_income_data = pinwheel_account.job_succeeded?("income")
        has_employment_data = pinwheel_account.job_succeeded?("employment")
        has_identity_data = pinwheel_account.job_succeeded?("identity")
        account_payments = payments.filter { |payment| payment.account_id == account_id }
        hash[account_id] ||= {
          total: account_payments.sum { |payment| payment.gross_pay_amount },
          has_income_data: has_income_data,
          has_employment_data: has_employment_data,
          has_identity_data: has_identity_data,
          income: has_income_data && incomes.find { |income| income.account_id == account_id },
          employment: has_employment_data && employments.find { |employment| employment.account_id == account_id },
          identity: has_identity_data && identities.find { |identity| identity.account_id == account_id },
          payments: account_payments
        }
      end
  end

  private

  def fetch_paystubs(from_pay_date, to_pay_date)
    @cbv_flow.payroll_accounts.flat_map do |pinwheel_account|
      next [] unless pinwheel_account.job_succeeded?("paystubs")

      fetch_paystubs_for_account_id(pinwheel_account.pinwheel_account_id, from_pay_date, to_pay_date)
    end
  end

  def fetch_paystubs_for_account_id(account_id, from_pay_date, to_pay_date)
    pinwheel.fetch_paystubs(
      account_id: account_id,
      from_pay_date: from_pay_date.strftime("%Y-%m-%d"),
      to_pay_date: to_pay_date.strftime("%Y-%m-%d")
    )
  end

  def does_pinwheel_account_support_job?(account_id, job)
    pinwheel_account = PayrollAccount.find_by_pinwheel_account_id(account_id)
    return false unless pinwheel_account

    pinwheel_account.job_succeeded?(job)
  end
end
