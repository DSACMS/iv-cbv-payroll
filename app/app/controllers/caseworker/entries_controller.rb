class Caseworker::EntriesController < ApplicationController
  def index
    @current_site = current_site
  end

  private

  def current_site
    site_config[params[:site_id]]
  end
end
