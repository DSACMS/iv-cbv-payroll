class MaintenanceController < ApplicationController
  skip_before_action :redirect_if_maintenance_mode

  def show
  end

  def technical_difficulties
    # Planned maintenance takes precedence when both full-site alerts are active.
    redirect_to_outage maintenance_path if ENV["MAINTENANCE_MODE"] == "true"
  end

  private

  def current_agency
    action_name == "technical_difficulties" ? agency_config[params[:client_agency_id]] : super
  end

  def session_timeout_enabled?
    action_name == "technical_difficulties" ? false : super
  end
end
