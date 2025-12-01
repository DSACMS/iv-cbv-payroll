class EducationActivity < ApplicationRecord
  belongs_to :identity
  has_many :enrollments, through: :education_activities_enrollments
end
