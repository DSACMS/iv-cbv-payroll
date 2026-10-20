class MaintenanceController < ApplicationController
  skip_before_action :redirect_if_maintenance_mode
  skip_after_action :remember_outage_agency

  def show
  end

  def technical_difficulties
    # Planned maintenance takes precedence when both full-site alerts are active.
    return redirect_to maintenance_path if ENV["MAINTENANCE_MODE"] == "true"

    @current_agency = outage_agency
  end

  private

  def activity_flow?
    if action_name == "technical_difficulties" && params[:reporting_flow].present?
      params[:reporting_flow] == "activity"
    else
      super
    end
  end

  def session_timeout_enabled?
    action_name == "technical_difficulties" ? false : super
  end
end
