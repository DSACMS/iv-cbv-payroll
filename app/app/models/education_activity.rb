class EducationActivity < ApplicationRecord
  belongs_to :identity
  has_many :enrollments
end
