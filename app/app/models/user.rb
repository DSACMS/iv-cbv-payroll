class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[ma_dta nyc_dss sandbox]
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :trackable, :timeoutable, :omniauthable

  has_many :api_access_tokens, dependent: :destroy

  def create_api_access_token
    ApiAccessToken.create(user: self).access_token
  end

  def self.find_by_access_token(token)
    ApiAccessToken.find_by(access_token: token, deleted_at: nil)&.user
  end
end
