class Cbv::SummariesController < Cbv::BaseController
  before_action :set_payments, only: %i[show]

  def show
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "#{@cbv_flow.id}"
      end
    end
  end

  def update
    @cbv_flow.update(summary_update_params)

    redirect_to next_path
  end

  private

  def summary_update_params
    params.fetch(:cbv_flow, {}).permit(:additional_information)
  end
end
