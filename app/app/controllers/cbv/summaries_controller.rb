class Cbv::SummariesController < Cbv::BaseController
  include Cbv::PaymentsHelper

  helper_method :payments_grouped_by_employer, :total_gross_income, :has_consent
  before_action :set_payments, only: %i[show update]
  skip_before_action :ensure_cbv_flow_not_yet_complete, if: -> { params[:format] == "pdf" }

  def show
    invitation = @cbv_flow.cbv_flow_invitation
    @summary_end_date= invitation ? invitation.snap_application_date.strftime("%B %d, %Y") : ""
    ninety_days_ago = invitation ? invitation.snap_application_date - 90.days : ""
    @summary_start_date= invitation ? ninety_days_ago.strftime("%B %d, %Y") : ""
    respond_to do |format|
      format.html
      format.pdf do
        NewRelicEventTracker.track("ApplicantDownloadedIncomePDF", {
          timestamp: Time.now.to_i,
          site_id: @cbv_flow.site_id,
          cbv_flow_id: @cbv_flow.id
        })

        render pdf: "#{@cbv_flow.id}", layout: "pdf"
      end
    end
  end

  def update
    unless has_consent
      return redirect_to(cbv_flow_summary_path, flash: { alert: t(".consent_to_authorize_warning") })
    end

    if params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
      timestamp = Time.now.to_datetime
      @cbv_flow.update(consented_to_authorized_use_at: timestamp)
    end

    if @cbv_flow.confirmation_code.blank?
      confirmation_code = generate_confirmation_code(@cbv_flow.site_id)
      @cbv_flow.update(confirmation_code: confirmation_code)
    end

    if !current_site.transmission_method.present?
      Rails.logger.info("No transmission method found for site #{current_site.id}")
    else
      transmit_to_caseworker
    end

    redirect_to next_path
  end

  private

  def has_consent
    return true if @cbv_flow.consented_to_authorized_use_at.present?
    params[:cbv_flow] && params[:cbv_flow][:consent_to_authorized_use] == "1"
  end

  def payments_grouped_by_employer
    summarize_by_employer(@payments)
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end

  def transmit_to_caseworker
    case current_site.transmission_method
    when "shared_email"
      CaseworkerMailer.with(
        email_address: current_site.transmission_method_configuration.dig("email"),
        cbv_flow: @cbv_flow,
        payments: @payments
      ).summary_email.deliver_now
      @cbv_flow.touch(:transmitted_at)
    end

    track_transmitted_event(@cbv_flow, @payments)
  end

  def track_transmitted_event(cbv_flow, payments)
    NewRelicEventTracker.track("IncomeSummarySharedWithCaseworker", {
      timestamp: Time.now.to_i,
      site_id: cbv_flow.site_id,
      cbv_flow_id: cbv_flow.id,
      account_count: payments.map { |p| p[:account_id] }.uniq.count,
      paystub_count: payments.count,
      account_count_with_additional_information:
        cbv_flow.additional_information.values.count { |info| info["comment"].present? },
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i
    })
  rescue => ex
    Rails.logger.error "Failed to track NewRelic event: #{ex.message}"
  end

  def generate_confirmation_code(prefix = nil)
    [
      prefix,
      (Time.now.to_i % 36 ** 3).to_s(36).tr("OISB", "0158").rjust(3, "0"),
      @cbv_flow.id.to_s.rjust(4, "0")
    ].compact.join.upcase
  end
end
