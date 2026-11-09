# frozen_string_literal: true

class Activities::Education::OtherController < Activities::BaseController
  after_action :track_viewed_event, only: :show

  def show
  end

  private

  def track_viewed_event
    return unless response.successful?

    track_event(TrackEvent::EducationOtherViewed)
  end
end
