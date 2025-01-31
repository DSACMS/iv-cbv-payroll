class ApiAccessToken < ApplicationRecord
  belongs_to :user

  encrypts :access_token, deterministic: true

  before_create do
    self.access_token = SecureRandom.urlsafe_base64
  end
end
