class Caseworker::EntriesController < Caseworker::BaseController
  def index
    @current_agency = current_agency
  end
end
