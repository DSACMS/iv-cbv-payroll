class Activities::ExpiredInvitationsController < ApplicationController
  before_action :redirect_unless_activity_hub_enabled

  def show
  end

  private

  def current_agency
    agency_config[params[:client_agency_id].presence || client_agency_from_domain]
  end

  def activity_flow?
    true
  end

  def session_timeout_enabled?
    false
  end
end
