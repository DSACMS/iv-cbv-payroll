class Api::HelpController < ApplicationController
  include CbvEventTracking

  EVENT_NAMES = %w[
    ApplicantOpenedHelpModal
  ]

  def user_action
    event_name = user_action_params[:event_name]
    event_attributes = { source: user_action_params[:source] }

    if EVENT_NAMES.include?(event_name)
      track_event(event_name, request, event_attributes)
      render json: { status: :ok }
    else
      raise "Unknown Event Type #{event_name.inspect}"
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to process user action: #{ex}"
    render json: { status: :error }, status: :unprocessable_entity
  end

  private

  def user_action_params
    params.permit(:event_name, :source)
  end
end
