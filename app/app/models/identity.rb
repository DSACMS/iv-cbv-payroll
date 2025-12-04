class Identity < ApplicationRecord
  has_many :activity_flows, dependent: :destroy
  has_many :schools, dependent: :destroy
end
