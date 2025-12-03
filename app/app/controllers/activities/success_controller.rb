class Activities::SuccessController < Activities::BaseController
  before_action :ensure_completed

  def show
  end

  private

  def ensure_completed
    redirect_to(activities_flow_summary_path) unless @activity_flow.completed_at
  end
end
