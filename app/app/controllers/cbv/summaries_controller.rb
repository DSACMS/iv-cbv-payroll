class Cbv::SummariesController < Cbv::BaseController
  include Cbv::PaymentsHelper

  helper_method :payments_grouped_by_employer, :total_gross_income
  before_action :set_payments, only: %i[show]
  skip_before_action :ensure_cbv_flow_not_yet_complete, if: -> { params[:format] == "pdf" }

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

    if params[:cbv_flow][:consent_to_authorized_use].eql?("1")
      timestamp = Time.now.to_datetime
      @cbv_flow.update(consented_to_authorized_use_at: timestamp)
      redirect_to next_path
    else
      redirect_to(cbv_flow_summary_path, flash: { alert: t(".consent_to_authorize_warning") })
    end
  end

  private

  def payments_grouped_by_employer
    summarize_by_employer(@payments)
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end
end
