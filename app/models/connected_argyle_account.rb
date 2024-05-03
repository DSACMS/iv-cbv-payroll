class ConnectedArgyleAccount < ApplicationRecord
  # Add validations here
  validates :user_id, presence: true
  validates :account_id, presence: true
end
