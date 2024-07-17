class Cbv::SummariesController < Cbv::BaseController
  helper_method :payments_grouped_by_employer, :total_gross_income
  before_action :set_payments, only: %i[show]

  def show
    respond_to do |format|
      format.html
      format.pdf do
        NewRelicEventTracker.track("ApplicantDownloadedIncomePDF", {
          timestamp: Time.now.to_i,
          cbv_flow_id: @cbv_flow.id
        })

        render pdf: "#{@cbv_flow.id}"
      end
    end
  end

  def update
    @cbv_flow.update(summary_update_params)

    redirect_to next_path
  end

  private

  def payments_grouped_by_employer
    @payments.each_with_object({}) do |payment, hash|
      account_id = payment[:account_id]
      hash[account_id] ||= {
        employer_name: payment[:employer],
        total: 0,
        payments: [],
      }
      hash[account_id][:total] += payment[:amount]
      hash[account_id][:payments] << payment
    end
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end

  def summary_update_params
    params.fetch(:cbv_flow, {}).permit(:additional_information)
  end
end
