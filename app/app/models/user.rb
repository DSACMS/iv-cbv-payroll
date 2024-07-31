class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[azure_activedirectory_v2]
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :rememberable, :trackable, :timeoutable, :omniauthable
end
