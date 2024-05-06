class ConnectedArgyleAccount < ApplicationRecord
  validates :user_id, presence: true
  validates :account_id, presence: true
end
