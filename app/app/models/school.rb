class School < ApplicationRecord
  belongs_to :identity
  has_many :enrollments
end
