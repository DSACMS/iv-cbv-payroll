class Cbv::PaymentDetailsController < Cbv::BaseController
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
    :account_comment

  def show
    account_id = params[:user][:account_id]
    pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(account_id)

    @employment = pinwheel.fetch_employment(account_id: account_id)["data"]
    @has_income_data = pinwheel_account.supported_jobs.include?("income")
    @income_metadata = @has_income_data && pinwheel.fetch_income_metadata(account_id: account_id)["data"]
    @payments = set_payments account_id
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

  def employer_name
    @employment["employer_name"]
  end

  def employment_start_date
    @employment["start_date"]
  end

  def employment_end_date
    @employment["termination_date"]
  end

  def employment_status
    @employment["status"]&.humanize
  end

  def pay_frequency
    @income_metadata["pay_frequency"]&.humanize
  end

  def compensation_unit
    @income_metadata["compensation_unit"]
  end

  def compensation_amount
    @income_metadata["compensation_amount"]
  end

  def start_date
    @payments
        .sort_by { |payment| payment[:start] }
        .first[:start]
  end

  def end_date
    @payments
        .sort_by { |payment| payment[:end] }
        .last[:end]
  end

  def gross_pay
    @payments
      .map { |payment| payment[:gross_pay_amount] }
      .reduce(:+)
  end

  def sanitize_comment(comment)
    ActionController::Base.helpers.sanitize(comment)
  end
end
