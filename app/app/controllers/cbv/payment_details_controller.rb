class Cbv::PaymentDetailsController < Cbv::BaseController
  include Cbv::AggregatorDataHelper
  helper_method :employer_name,
    :gross_pay,
    :employment_start_date,
    :employment_end_date,
    :employment_status,
    :pay_frequency,
    :compensation_unit,
    :compensation_amount,
    :account_comment,
    :has_income_data?

  after_action :track_viewed_event, only: :show
  after_action :track_saved_event, only: :update

  def show
    account_id = params[:user][:account_id]
    @pinwheel_account = @cbv_flow.payroll_accounts.find_by(pinwheel_account_id: account_id)

    # security check - make sure the account_id is associated with the current cbv_flow_id
    if @pinwheel_account.nil?
      return redirect_to(cbv_flow_entry_url, flash: { slim_alert: { message: t("cbv.error_no_access"), type: "error" } })
    end

    set_aggregator_report_for_account(@pinwheel_account)
    @payroll_account_report = @aggregator_report.find_account_report(account_id)
    @account_comment = account_comment
  end

  def update
    account_id = params[:user][:account_id]
    comment = params[:cbv_flow][:additional_information]
    additional_information = @cbv_flow.additional_information
    additional_information[account_id] = {
      comment: sanitize_comment(comment),
      updated_at: Time.current
    }
    @cbv_flow.update(additional_information: additional_information)

    redirect_to next_path
  end

  def account_comment
    account_id = params[:user][:account_id]
    get_comment_by_account_id(account_id)["comment"]
  end

  private

  def has_income_data?
    @pinwheel_account.job_succeeded?("income")
  end

  def has_employment_data?
    @pinwheel_account.job_succeeded?("employment")
  end

  def has_paystubs_data?
    @pinwheel_account.job_succeeded?("paystubs")
  end

  def employer_name
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?

    @payroll_account_report.employment.employer_name
  end

  def employment_start_date
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?

    @payroll_account_report.employment.start_date
  end

  def employment_end_date
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?

    @payroll_account_report.employment.termination_date
  end

  def employment_status
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?

    @payroll_account_report.employment.status&.humanize
  end

  def pay_frequency
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?

    @payroll_account_report.income.pay_frequency&.humanize
  end

  def compensation_unit
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?

    @payroll_account_report.income.compensation_unit
  end

  def compensation_amount
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?

    @payroll_account_report.income.compensation_amount
  end

  def gross_pay
    return I18n.t("cbv.payment_details.show.unknown") unless has_paystubs_data?

    @payroll_account_report.paystubs
      .map { |paystub| paystub.gross_pay_amount.to_i }
      .reduce(:+)
  end

  def sanitize_comment(comment)
    ActionController::Base.helpers.sanitize(comment)
  end

  def track_viewed_event
    return if @pinwheel_account.nil?
    event_logger.track("ApplicantViewedPaymentDetails", request, {
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      pinwheel_account_id: @pinwheel_account.id,
      payments_length: @payroll_account_report.paystubs.length,
      has_employment_data: has_employment_data?,
      has_paystubs_data: has_paystubs_data?,
      has_income_data: has_income_data?
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantViewedPaymentDetails): #{ex}"
  end

  def track_saved_event
    comment_data = @cbv_flow.additional_information[params[:user][:account_id]]

    event_logger.track("ApplicantSavedPaymentDetails", request, {
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      additional_information_length: comment_data ? comment_data["comment"].length : 0
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSavedPaymentDetails): #{ex}"
  end
end
