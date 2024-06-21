class Cbv::EmployerSearchesController < Cbv::BaseController
  def show
    @query = search_params[:query]
    @employers = @query.blank? ? [] : fetch_employers(@query)
  end

  private

  def search_params
    params.permit(:query)
  end

  def fetch_employers(query = "")
    request_params = {
      q: query,
      supported_jobs: [ "paystubs" ]
    }

    pinwheel.fetch_items(request_params)["data"]
  end
end
