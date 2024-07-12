class Cbv::PaymentDetailsController < Cbv::BaseController
  helper_method :employer_name, :start_date, :end_date, :gross_pay

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
end
