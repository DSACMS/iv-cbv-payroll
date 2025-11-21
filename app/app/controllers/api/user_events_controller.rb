class Api::UserEventsController < ApplicationController
  def user_action
    base_attributes = {
      time: Time.now.to_i
    }

    if session[:cbv_flow_id].present?
      @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

      base_attributes.merge!({
        cbv_flow_id: @cbv_flow.id,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        client_agency_id: @cbv_flow.client_agency_id,
        device_id: @cbv_flow.device_id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id
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
