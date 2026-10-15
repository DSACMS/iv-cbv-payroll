class Activities::SuccessController < Activities::BaseController
  before_action :ensure_completed

  def show
  end

  def show_activity_reporting_banner?
    false
  end

  private

  def ensure_completed
    redirect_to(activities_flow_summary_path) unless @flow.completed_at
  end
end
