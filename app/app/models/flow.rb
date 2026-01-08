class Flow < ApplicationRecord
  self.abstract_class = true

  has_many :payroll_accounts, as: :flow, dependent: :destroy
end
