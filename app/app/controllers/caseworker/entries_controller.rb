class Caseworker::EntriesController < ApplicationController
  def index
    @current_site = current_site
  end
end
