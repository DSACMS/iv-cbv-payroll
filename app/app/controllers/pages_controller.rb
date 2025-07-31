class PagesController < ApplicationController
  before_action :redirect_to_client_agency_entries, only: %i[home]

  def home
  end

  def error_404
    # When in development environment, you'll need to set
    #   config.consider_all_requests_local = false
    # in config/development.rb for these pages to actually show up.
    @cbv_flow = if session[:cbv_flow_id]
                  CbvFlow.find(session[:cbv_flow_id])
                end

    render status: :not_found, formats: %i[html]
  end

  def error_500
    # When in development environment, you'll need to set
    #   config.consider_all_requests_local = false
    # in config/development.rb for these pages to actually show up.

    render status: :internal_server_error, formats: %i[html]
  end

  private

  def redirect_to_client_agency_entries
    # Don't redirect to CBV flow if the pilot has ended - let the home page render the pilot end message
    return if pilot_ended?

    client_agency_id = detect_client_agency_from_domain
    if client_agency_id.present?
      agency = agency_config[client_agency_id]
      session[:cbv_origin] = params[:origin] || agency&.default_origin
      redirect_to cbv_flow_new_path(client_agency_id: client_agency_id)
    end
  end
end
