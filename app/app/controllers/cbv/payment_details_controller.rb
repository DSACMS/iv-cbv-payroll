class Cbv::PaymentDetailsController < Cbv::BaseController
  include Cbv::PaymentsHelper

  helper_method :employer_name,
    :start_date,
    :end_date,
    :gross_pay,
    :employment_start_date,
    :employment_end_date,
    :employment_status,
    :pay_frequency,
    :compensation_unit,
    :compensation_amount,
    :account_comment,
    :has_income_data?

  def show
    account_id = params[:user][:account_id]
    @pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(account_id)
    @employment = has_employment_data? && pinwheel.fetch_employment(account_id: account_id)["data"]
    @income_metadata = has_income_data? && pinwheel.fetch_income_metadata(account_id: account_id)["data"]
    @payments = has_paystubs_data? ? set_payments(account_id) : []
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
    @pinwheel_account.supported_jobs.include?("income") && @pinwheel_account.income_errored_at.blank?
  end

  def has_employment_data?
    @pinwheel_account.supported_jobs.include?("employment") && @pinwheel_account.employment_errored_at.blank?
  end

  def has_paystubs_data?
    @pinwheel_account.supported_jobs.include?("paystubs") && @pinwheel_account.paystubs_errored_at.blank?
  end

  def employer_name
    @employment ? @employment["employer_name"] : I18n.t("cbv.payment_details.show.unknown")
  end

  def employment_start_date
    @employment ? @employment["start_date"] : I18n.t("cbv.payment_details.show.unknown")
  end

  def employment_end_date
    @employment ? @employment["termination_date"] : I18n.t("cbv.payment_details.show.unknown")
  end

  def employment_status
    @employment ? @employment["status"]&.humanize : I18n.t("cbv.payment_details.show.unknown")
  end

  def pay_frequency
    @income_metadata ? @income_metadata["pay_frequency"]&.humanize : I18n.t("cbv.payment_details.show.unknown")
  end

  def compensation_unit
    @income_metadata ? @income_metadata["compensation_unit"] : I18n.t("cbv.payment_details.show.unknown")
  end

  def compensation_amount
    @income_metadata ? @income_metadata["compensation_amount"] : I18n.t("cbv.payment_details.show.unknown")
  end

  def start_date
    @payments.present? ? @payments
        .sort_by { |payment| payment[:start] }
        .first[:start] : I18n.t("cbv.payment_details.show.unknown")
  end

  def end_date
    @payments.present? ? @payments
        .sort_by { |payment| payment[:end] }
        .last[:end] : I18n.t("cbv.payment_details.show.unknown")
  end

  def gross_pay
    @payments.present? ? @payments
      .map { |payment| payment[:gross_pay_amount] }
      .reduce(:+) : I18n.t("cbv.payment_details.show.unknown")
  end

  def sanitize_comment(comment)
    ActionController::Base.helpers.sanitize(comment)
  end
end
