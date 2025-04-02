class Cbv::SummariesController < Cbv::BaseController
  include Cbv::AggregatorDataHelper

  before_action :set_aggregator_report, only: %i[show]

  def show
    track_accessed_income_summary_event(@cbv_flow, @aggregator_report.paystubs)
  end

  def track_accessed_income_summary_event(cbv_flow, payments)
    event_logger.track("ApplicantAccessedIncomeSummary", request, {
      timestamp: Time.now.to_i,
      client_agency_id: cbv_flow.client_agency_id,
      cbv_flow_id: cbv_flow.id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      account_count: cbv_flow.payroll_accounts.count,
      paystub_count: @aggregator_report.paystubs.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i,
      language: I18n.locale
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantAccessedIncomeSummary): #{ex}"
  end
end
