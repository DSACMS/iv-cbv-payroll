class Cbv::SummariesController < Cbv::BaseController
  include Cbv::PinwheelDataHelper

  before_action :set_employments, only: %i[show]
  before_action :set_incomes, only: %i[show]
  before_action :set_payments, only: %i[show]
  before_action :set_identities, only: %i[show]

  def show
    track_accessed_income_summary_event(@cbv_flow, @payments)
  end

  def track_accessed_income_summary_event(cbv_flow, payments)
    event_logger.track("ApplicantAccessedIncomeSummary", request, {
      timestamp: Time.now.to_i,
      client_agency_id: cbv_flow.client_agency_id,
      cbv_flow_id: cbv_flow.id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      account_count: cbv_flow.payroll_accounts.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i,
      language: I18n.locale
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantAccessedIncomeSummary): #{ex}"
  end
end
