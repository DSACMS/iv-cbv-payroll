class ApiAccessToken < ApplicationRecord
  belongs_to :user

  has_secure_password :access_token, validations: false

  before_create do
    self.access_token = SecureRandom.urlsafe_base64
  end
end
