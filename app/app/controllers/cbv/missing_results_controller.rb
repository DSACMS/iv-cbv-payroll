class Cbv::MissingResultsController < Cbv::BaseController
  before_action :track_missing_results_event, only: :show

  def show
    @has_payroll_account = @cbv_flow.payroll_accounts.any?
  end

  def track_missing_results_event
    event_logger.track(TrackEvent::ApplicantAccessedMissingResultsPage, request, {
      time: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      client_agency_id: current_agency&.id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  end
end
