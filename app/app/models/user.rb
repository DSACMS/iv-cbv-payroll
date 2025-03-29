class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[ma_dta nyc_dss az_des sandbox]
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :trackable, :timeoutable, :omniauthable

  has_many :api_access_tokens, dependent: :destroy

  def self.find_by_access_token(token)
    token_user = ApiAccessToken.find_by(access_token: token, deleted_at: nil)&.user

    token_user if token_user && token_user.is_service_account
  end
end
