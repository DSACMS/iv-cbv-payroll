class Activities::Income::PayrollConsentsController < Activities::BaseController
  def show
    render json: { consented: @flow.payroll_consented_at.present? }
  end

  def create
    return head :unprocessable_entity unless params[:consent] == "1"

    @flow.with_lock do
      @flow.update!(payroll_consented_at: Time.current) unless @flow.payroll_consented_at?
    end
    render json: { consented: true }
  end
end
