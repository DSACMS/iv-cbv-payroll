class Cbv::PaymentDetailsController < Cbv::BaseController
  helper_method :employer_name, :day_count, :start_date, :end_date

  def show
    account_id = params[:user][:account_id]
    @payments = set_payments account_id
  end

  private

  def employer_name
    if @payments.any?
        @payments.first[:employer_name]
    end
  end

  def day_count
    (Date.parse(end_date) - Date.parse(start_date)).to_i
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
end
