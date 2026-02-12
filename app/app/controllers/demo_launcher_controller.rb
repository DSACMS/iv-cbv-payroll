class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?

  def show
  end

  def create
    client_agency_id = params[:client_agency_id]
    launch_type = params[:launch_type]

    overrides = {}
    overrides[:reporting_window] = params[:reporting_window] if params[:reporting_window].present?
    overrides[:reporting_window_months] = params[:reporting_window_months] if params[:reporting_window_months].present?
    overrides[:demo_timeout] = params[:demo_timeout] if params[:demo_timeout].present?

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
    base_url = Rails.application.routes.url_helpers.activities_flow_new_url(
      client_agency_id: client_agency_id,
      host: request.host_with_port,
      protocol: request.protocol
    )
    append_params(base_url, overrides)
  end

  def build_tokenized_url(client_agency_id, overrides)
    invitation = ActivityFlowInvitation.create!(
      client_agency_id: client_agency_id,
      reference_id: "demo-#{SecureRandom.hex(4)}"
    )
    base_url = invitation.to_url(
      host: request.host_with_port,
      protocol: request.protocol,
      reporting_window: overrides[:reporting_window]
    )
    append_params(base_url, overrides.except(:reporting_window))
  end

  def append_params(url, extra_params)
    return url if extra_params.blank?

    uri = URI.parse(url)
    existing = Rack::Utils.parse_query(uri.query)
    existing.merge!(extra_params.stringify_keys)
    uri.query = existing.to_query.presence
    uri.to_s
  end
end
