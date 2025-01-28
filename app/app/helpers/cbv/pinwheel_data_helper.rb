module Cbv::PinwheelDataHelper
  include ViewHelper

  def set_payments(account_id = nil)
    invitation = @cbv_flow.cbv_flow_invitation
    to_pay_date = invitation.snap_application_date
    from_pay_date = invitation.paystubs_query_begins_at
    payments = account_id.nil? ? fetch_payroll(from_pay_date.strftime("%Y-%m-%d"), to_pay_date.strftime("%Y-%m-%d")) : fetch_payroll_for_account_id(account_id, from_pay_date.strftime("%Y-%m-%d"), to_pay_date.strftime("%Y-%m-%d"))
    @payments_ending_at = format_date(to_pay_date)
    @payments_beginning_at = format_date(from_pay_date)
    @payments = parse_payments(payments)
  end

  def set_employments(account_id = nil)
    @employments = account_id.nil? ? fetch_employments : fetch_employments_for_account_id(account_id)
  end

  def set_incomes(account_id = nil)
    @incomes = account_id.nil? ? fetch_incomes : fetch_incomes_for_account_id(account_id)
  end

  def set_identities(account_id = nil)
    @identities = account_id.nil? ? fetch_identities : fetch_identity_for_account_id(account_id)
  end

  def parse_payments(payments)
    payments.map do |payment|
      {
        start: payment["pay_period_start"],
        end: payment["pay_period_end"],
        hours: total_hours_from_earnings(payment["earnings"]),
        hours_by_earning_category: hours_by_earning_category(payment["earnings"]),
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
    pinwheel_account_ids = pinwheel.fetch_accounts(end_user_id: @cbv_flow.pinwheel_end_user_id)["data"].pluck("id")

    PinwheelAccount.where(pinwheel_account_id: pinwheel_account_ids).pluck(:pinwheel_account_id)
  end

  def total_hours_from_earnings(earnings)
    base_hours = earnings
      .filter { |e| e["category"] != "overtime" }
      .map { |e| e["hours"] }
      .compact
      .max
    return unless base_hours

    # Add overtime hours to the base hours, because they tend to be additional
    # work beyond the other entries. (As opposed to category="premium", which
    # often duplicates other earnings' hours.)
    #
    # See FFS-1773.
    overtime_hours = earnings
      .filter { |e| e["category"] == "overtime" }
      .sum { |e| e["hours"] || 0.0 }

    base_hours + overtime_hours
  end

  def hours_by_earning_category(earnings)
    earnings
      .filter { |e| e["hours"].present? && e["hours"] > 0 }
      .group_by { |e| e["category"] }
      .transform_values { |earnings| earnings.sum { |e| e["hours"] } }
  end

  def payments_grouped_by_employer
    summarize_by_employer(@payments, @employments, @incomes, @identities, @cbv_flow.pinwheel_accounts)
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end

  def summarize_by_employer(payments, employments, incomes, identities, pinwheel_accounts)
    pinwheel_accounts
      .each_with_object({}) do |pinwheel_account, hash|
        account_id = pinwheel_account.pinwheel_account_id
        has_income_data = pinwheel_account.job_succeeded?("income")
        has_employment_data = pinwheel_account.job_succeeded?("employment")
        has_identity_data = pinwheel_account.job_succeeded?("identity")
        account_payments = payments.filter { |payment| payment[:account_id] == account_id }
        hash[account_id] ||= {
          total: account_payments.sum { |payment| payment[:gross_pay_amount] },
          payments: account_payments,
          has_income_data: has_income_data,
          has_employment_data: has_employment_data,
          has_identity_data: has_identity_data,
          income: has_income_data && incomes.find { |income| income["account_id"] == account_id },
          employment: has_employment_data && employments.find { |employment| employment["account_id"] == account_id },
          identity: has_identity_data && identities.find { |identity| identity["account_id"] == account_id }
        }
      end
  end

  private

  def fetch_payroll(from_pay_date, to_pay_date)
    fetch_known_end_user_account_ids.map do |account_id|
      fetch_payroll_for_account_id(account_id, from_pay_date, to_pay_date)
    end.flatten
  end

  def fetch_payroll_for_account_id(account_id, from_pay_date, to_pay_date)
    pinwheel.fetch_paystubs(account_id: account_id, from_pay_date: from_pay_date, to_pay_date: to_pay_date)["data"]
  end

  def fetch_employments
    fetch_known_end_user_account_ids.map do |account_id|
      next [] unless does_pinwheel_account_support_job?(account_id, "employment")
      fetch_employments_for_account_id account_id
    end.flatten
  end

  def fetch_employments_for_account_id(account_id)
    pinwheel.fetch_employment(account_id: account_id)["data"]
  end

  def fetch_incomes
    fetch_known_end_user_account_ids.map do |account_id|
      next [] unless does_pinwheel_account_support_job?(account_id, "income")
      fetch_incomes_for_account_id account_id
    end.flatten
  end

  def fetch_incomes_for_account_id(account_id)
    pinwheel.fetch_income_metadata(account_id: account_id)["data"]
  end

  def fetch_identities
    fetch_known_end_user_account_ids.map do |account_id|
      next [] unless does_pinwheel_account_support_job?(account_id, "identity")
      fetch_identity_for_account_id account_id
    end.flatten
  end

  def fetch_identity_for_account_id(account_id)
    pinwheel.fetch_identity(account_id: account_id)["data"]
  end

  def does_pinwheel_account_support_job?(account_id, job)
    pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(account_id)
    return false unless pinwheel_account

    pinwheel_account.job_succeeded?(job)
  end
end
