class Api::HelpController < ApplicationController
  EVENT_NAMES = %w[
    ApplicantOpenedHelpModal
  ]

  def user_action
    base_attributes = {
      timestamp: Time.now.to_i
    }

    event_name = user_action_params[:event_name]
    event_attributes = base_attributes.merge(source: user_action_params[:source])

    if EVENT_NAMES.include?(event_name)
      event_logger.track(
        event_name,
        request,
        event_attributes.to_h
      )
    else
      raise "Unknown Event Type #{event_name.inspect}"
    end

    render json: { status: :ok }
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