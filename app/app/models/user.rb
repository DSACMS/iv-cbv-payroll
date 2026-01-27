class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :trackable, :timeoutable

  has_many :api_access_tokens, dependent: :destroy

  def self.find_by_access_token(token)
    token_user = ApiAccessToken.find_by(access_token: token, deleted_at: nil)&.user

    token_user if token_user && token_user.is_service_account
  end

  def self.api_key_for_agency(agency_id)
    user = find_by(client_agency_id: agency_id, is_service_account: true)
    return nil unless user

    oldest_token = user.api_access_tokens
      .where(deleted_at: nil)
      .order(:created_at)
      .first

    oldest_token&.access_token
  end
end
