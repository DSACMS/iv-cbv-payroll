class Cbv::EmployerSearchesController < Cbv::BaseController
  # Disable CSP since Pinwheel relies on inline styles
  content_security_policy false, only: :show
  after_action :track_event, only: :show

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

  def track_event
    return if @query.blank?

    NewRelicEventTracker.track("ApplicantSearchedForEmployer", {
      cbv_flow_id: @cbv_flow.id,
      num_results: @employers.length,
      has_pinwheel_account: @has_pinwheel_account
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSearchedForEmployer): #{ex}"
  end
end
