class Caseworker::EntriesController < Caseworker::BaseController
  def index
    @current_site = current_site
  end
end
