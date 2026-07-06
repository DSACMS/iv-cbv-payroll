class Household < ApplicationRecord
  has_many :household_members, dependent: :destroy

  has_secure_token :auth_token, length: 10

  validates :client_agency_id, inclusion: Rails.application.config.client_agencies.client_agency_ids
  validates :reference_id, presence: true, uniqueness: true

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.household_start_url(token: auth_token, host: host, **url_params)
  end
end
