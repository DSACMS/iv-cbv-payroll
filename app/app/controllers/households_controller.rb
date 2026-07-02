class HouseholdsController < ApplicationController
  before_action :redirect_unless_activity_hub_enabled, :set_household

  def show
    set_flow_session(nil, :activity)
  end

  private

  def set_household
    @household = Household.find_by(auth_token: normalize_token(params[:token]))
    return if @household

    redirect_to root_url, flash: { alert: t("households.errors.invalid_token") }
  end

  def current_agency
    return agency_config[@household.client_agency_id] if @household

    super
  end
end
