class Identity < ApplicationRecord
  has_many :activity_flows, dependent: :destroy
end
