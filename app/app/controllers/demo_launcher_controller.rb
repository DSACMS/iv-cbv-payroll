class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?

  def show
  end

  def create
    client_agency_id = params[:client_agency_id]
    launch_type = params[:launch_type]

    overrides = params.permit(:reporting_window, :reporting_window_months, :demo_timeout).select { |_, v| v.present? }

    url = if launch_type == "generic"
            build_generic_url(client_agency_id, overrides)
          else
            build_tokenized_url(client_agency_id, overrides)
          end

    redirect_to url, allow_other_host: true
  end

  private

  def session_timeout_enabled?
    false
  end

  def build_generic_url(client_agency_id, overrides)
    Rails.application.routes.url_helpers.activities_flow_new_url(
      client_agency_id: client_agency_id,
      host: request.host_with_port,
      protocol: request.protocol,
      **overrides
    )
  end

  def build_tokenized_url(client_agency_id, overrides)
    invitation = ActivityFlowInvitation.create!(
      client_agency_id: client_agency_id,
      reference_id: "demo-#{SecureRandom.hex(4)}"
    )
    invitation.to_url(
      host: request.host_with_port,
      protocol: request.protocol,
      **overrides
    )
  end
end
