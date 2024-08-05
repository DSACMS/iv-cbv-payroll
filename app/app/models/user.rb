class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[ma_dta nyc_dss sandbox]
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :trackable, :timeoutable, :omniauthable
end
