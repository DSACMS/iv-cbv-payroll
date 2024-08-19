class Caseworker::EntriesController < ApplicationController
  def index
    @current_site = current_site
  end

  private

  def current_site
    site_config[params[:site_id]]
  end

  def agency_short_name
    current_site.agency_short_name
  end
end
