require "csv"
require "tempfile"
require "zlib"

class Cbv::SubmitsController < Cbv::BaseController
  include Cbv::AggregatorDataHelper
  include GpgEncryptable
  include TarFileCreatable
  include CsvHelper

  before_action :set_aggregator_report, only: %i[show update]

  helper "cbv/aggregator_data"

  helper_method :has_consent
  skip_before_action :ensure_cbv_flow_not_yet_complete, if: -> { params[:format] == "pdf" }

  def show
    respond_to do |format|
      format.html
      format.pdf do
        event_logger.track("ApplicantDownloadedIncomePDF", request, {
          timestamp: Time.now.to_i,
          client_agency_id: current_agency&.id,
          cbv_applicant_id: @cbv_flow.cbv_applicant_id,
          cbv_flow_id: @cbv_flow.id,
          invitation_id: @cbv_flow.cbv_flow_invitation_id,
          locale: I18n.locale
        })

        render pdf: "#{@cbv_flow.id}",
          layout: "pdf",
          locals: {
            is_caseworker: (Rails.env.development? || Rails.env.test?) && params[:is_caseworker],
            aggregator_report: @aggregator_report
          },
          footer: { right: "Income Verification Report | Page [page] of [topage]", font_size: 10 },
          margin:  {
            top:               10,
            bottom:            10,
            left:              10,
            right:             10
          }
      end
    end

    track_accessed_submit_event(@cbv_flow)
  end

  def update
    unless has_consent
      @cbv_flow.errors.add(:consent_to_authorized_use, :blank, message: t(".consent_to_authorize_warning"))
      return redirect_to(cbv_flow_submit_path, flash: { alert: t(".consent_to_authorize_warning") })
    end

    if params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
      timestamp = Time.now.to_datetime
      @cbv_flow.update(consented_to_authorized_use_at: timestamp)
    end

    if ENV["ACTIVEJOB_ENABLED"] == "true"
      CaseWorkerTransmitterJob.perform_later(@cbv_flow.id)
    else
      CaseWorkerTransmitterJob.perform_now(@cbv_flow.id)
    end

    redirect_to next_path
  end

  private

  def has_consent
    return true if @cbv_flow.consented_to_authorized_use_at.present?
    params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
  end

  def track_accessed_submit_event(cbv_flow)
    event_logger.track("ApplicantAccessedSubmitPage", request, {
      timestamp: Time.now.to_i,
      client_agency_id: current_agency&.id,
      cbv_flow_id: cbv_flow.id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i,
      locale: I18n.locale
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantAccessedIncomeSummary): #{ex}"
  end
end
