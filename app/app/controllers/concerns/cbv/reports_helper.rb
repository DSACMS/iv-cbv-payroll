# This helper should become the future home of payments_helper

module Cbv::ReportsHelper
  include Cbv::PaymentsHelper

  def payments_grouped_by_employer
    summarize_by_employer(@payments, @employments, @incomes, @identities)
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

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end

  def summarize_by_employer(payments, employments, incomes, identities)
    payments
      .each_with_object({}) do |payment, hash|
        account_id = payment[:account_id]
        pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(account_id)
        has_income_data = pinwheel_account.job_succeeded?("income")
        has_employment_data = pinwheel_account.job_succeeded?("employment")
        hash[account_id] ||= {
          employer_name: payment[:employer],
          total: 0,
          payments: [],
          has_income_data: has_income_data,
          has_employment_data: has_employment_data,
          income: has_income_data && incomes.find { |income| income["account_id"] == account_id },
          employment: has_employment_data && employments.find { |employment| employment["account_id"] == account_id },
          identity: identities.find { |identity| identity["account_id"] == account_id }
        }
        hash[account_id][:total] += payment[:gross_pay_amount]
        hash[account_id][:payments] << payment
      end
  end

  private

  def fetch_employments
    fetch_end_user_account_ids.map do |account_id|
      next [] unless does_pinwheel_account_support_job?(account_id, "employment")
      fetch_employments_for_account_id account_id
    end.flatten
  end

  def fetch_employments_for_account_id(account_id)
    pinwheel.fetch_employment(account_id: account_id)["data"]
  end

  def fetch_incomes
    fetch_end_user_account_ids.map do |account_id|
      next [] unless does_pinwheel_account_support_job?(account_id, "income")
      fetch_incomes_for_account_id account_id
    end.flatten
  end

  def fetch_incomes_for_account_id(account_id)
    pinwheel.fetch_income_metadata(account_id: account_id)["data"]
  end

  def fetch_identities
    fetch_end_user_account_ids.map do |account_id|
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
