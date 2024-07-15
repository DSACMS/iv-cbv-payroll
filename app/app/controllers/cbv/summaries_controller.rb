class Cbv::SummariesController < Cbv::BaseController
  helper_method :group_payments_by_employer
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

  def group_payments_by_employer
    @payments.group_by { |payment| payment[:account_id] }
  end

  def summary_update_params
    params.fetch(:cbv_flow, {}).permit(:additional_information)
  end
end
