class ActivityFlow < ApplicationRecord
  has_many :volunteering_activities, dependent: :destroy
end
