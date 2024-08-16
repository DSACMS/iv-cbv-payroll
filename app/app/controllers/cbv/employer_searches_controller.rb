class Cbv::EmployerSearchesController < Cbv::BaseController
  # Disable CSP since Pinwheel relies on inline styles
  content_security_policy false, only: :show

  def show
    @query = search_params[:query]
    @employers = @query.blank? ? [] : fetch_employers(@query)
    @has_pinwheel_account = @cbv_flow.pinwheel_accounts.any?
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
