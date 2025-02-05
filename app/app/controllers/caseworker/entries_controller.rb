class Caseworker::EntriesController < Caseworker::BaseController
  def index
    @current_client_agency = current_client_agency
  end
end
