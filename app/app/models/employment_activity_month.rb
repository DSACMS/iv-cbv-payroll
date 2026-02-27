class EmploymentActivityMonth < ApplicationRecord
  belongs_to :employment_activity

  validates :month, presence: true
  validates :hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gross_income, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
