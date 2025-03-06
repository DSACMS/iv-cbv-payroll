require "csv"
require "tempfile"
require "zlib"

class Cbv::SummariesController < Cbv::BaseController
  include Cbv::PinwheelDataHelper

  before_action :set_employments, only: %i[show update]
  before_action :set_incomes, only: %i[show update]
  before_action :set_payments, only: %i[show update]
  before_action :set_identities, only: %i[show update]

  def show
    respond_to do |format|
      format.html
      format.pdf do
        event_logger.track("ApplicantDownloadedIncomePDF", request, {
          timestamp: Time.now.to_i,
          client_agency_id: @cbv_flow.client_agency_id,
          cbv_applicant_id: @cbv_flow.cbv_applicant_id,
          cbv_flow_id: @cbv_flow.id,
          invitation_id: @cbv_flow.cbv_flow_invitation_id,
          locale: I18n.locale
        })

        render pdf: "#{@cbv_flow.id}",
          layout: "pdf",
          locals: { is_caseworker: Rails.env.development? && params[:is_caseworker] },
          footer: { right: "Income Verification Report | Page [page] of [topage]", font_size: 10 },
          margin:  {
            top:               10,
            bottom:            10,
            left:              10,
            right:             10
          }
      end
    end

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
