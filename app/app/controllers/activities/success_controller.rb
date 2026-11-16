class Activities::SuccessController < Activities::BaseController
  skip_before_action :ensure_activity_flow_not_yet_complete, only: :show
  before_action :ensure_completed
  after_action :track_confirmation_viewed_event, only: :show

  def show
  end

  def show_activity_reporting_banner?
    false
  end

  private

  def ensure_completed
    redirect_to(activities_flow_summary_path) unless @flow.completed_at
  end

  def track_confirmation_viewed_event
    return unless response.successful?

    track_event(TrackEvent::ActivityReportConfirmationViewed)
  end
end
