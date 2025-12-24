class Flow < ApplicationRecord
  self.abstract_class = true

  has_many :payroll_accounts, as: :flow, dependent: :destroy

  def has_account_with_required_data?
    payroll_accounts.any?(&:sync_succeeded?)
  end

  def fully_synced_payroll_accounts
    payroll_accounts.select { |account| account.has_fully_synced? }
  end
end
