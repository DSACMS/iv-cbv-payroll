class VolunteeringActivityMonth < ApplicationRecord
  FIELDS = %w[month hours].freeze

  belongs_to :volunteering_activity

  validates :month, presence: true
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
end
