class Flow < ApplicationRecord
  self.abstract_class = true

  has_many :payroll_accounts, as: :flow, dependent: :destroy

  def self.flow_attributes_from_params(params)
    {}
  end

  def has_account_with_required_data?
    payroll_accounts.any?(&:sync_succeeded?)
  end

  def fully_synced_payroll_accounts
    payroll_accounts.select { |account| account.has_fully_synced? }
  end

  def aggregator_lookback_days
    nil
  end

  def reporting_window_display
    nil
  end

  def after_payroll_sync_succeeded(_payroll_account, _report)
    nil
  end
end
