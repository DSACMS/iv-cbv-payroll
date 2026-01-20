class Api::UserEventsController < ApplicationController
  def user_action
    base_attributes = {
      time: Time.now.to_i
    }

    if session[:flow_id].present?
      @flow = flow_class.find(session[:flow_id])

      base_attributes.merge!({
        cbv_flow_id: @flow.id,
        cbv_applicant_id: @flow.cbv_applicant_id,
        client_agency_id: @flow.cbv_applicant.client_agency_id,
        device_id: @flow.device_id,
        invitation_id: @flow.invitation_id
      })
    end

    event_attributes = (user_action_params[:attributes] || {}).merge(base_attributes)
    event_name = user_action_params[:event_name]

    if TrackEvent.constants.map(&:to_s).include?(event_name)
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
    render json: { status: :error }, status: :unprocessable_content
  end

  private

  def user_action_params
    params.fetch(:events, {}).permit(:event_name, attributes: {})
  end
end
