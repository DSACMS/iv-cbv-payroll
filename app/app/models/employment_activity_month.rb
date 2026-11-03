class EmploymentActivityMonth < ApplicationRecord
  include Redactable

  has_redactable_fields(
    gross_income: :decimal
  )

  FIELDS = %w[month hours gross_income].freeze

  belongs_to :employment_activity

  validates :month, presence: true
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :gross_income, numericality: { greater_than_or_equal_to: 0 }
end
