class Cbv::SummariesController < Cbv::BaseController
  include Cbv::ReportsHelper

  helper_method :payments_grouped_by_employer, :total_gross_income
  before_action :set_payments, only: %i[show]
  before_action :set_employments, only: %i[show]
  before_action :set_incomes, only: %i[show]
  skip_before_action :ensure_cbv_flow_not_yet_complete, if: -> { params[:format] == "pdf" }

  def show
    @already_consented = @cbv_flow.consented_to_authorized_use_at ? true : false
    invitation = @cbv_flow.cbv_flow_invitation
    @summary_end_date= invitation ? invitation.snap_application_date.strftime("%B %d, %Y") : ""
    ninety_days_ago = invitation ? invitation.snap_application_date - 90.days : ""
    @summary_start_date= invitation ? ninety_days_ago.strftime("%B %d, %Y") : ""
    respond_to do |format|
      format.html
      format.pdf do
        NewRelicEventTracker.track("ApplicantDownloadedIncomePDF", {
          timestamp: Time.now.to_i,
          cbv_flow_id: @cbv_flow.id
        })

        render pdf: "#{@cbv_flow.id}", layout: "pdf"
      end
    end
  end

  def update
    # User has previously consented, so checkbox field is not in the form
    if @cbv_flow.consented_to_authorized_use_at
      redirect_to next_path
    # User has NOT previously consented, but checked the box
    elsif params[:cbv_flow][:consent_to_authorized_use].eql?("1")
      timestamp = Time.now.to_datetime
      @cbv_flow.update(consented_to_authorized_use_at: timestamp)
      redirect_to next_path
    # User has NOT previously consented or checked the box
    else
      flash[:slim_alert] = { message: t(".consent_to_authorize_warning"), type: "error" }
      redirect_to cbv_flow_summary_path
    end
  end

  private

  def payments_grouped_by_employer
    summarize_by_employer(@payments, @employments, @incomes)
  end

  def total_gross_income
    @payments.reduce(0) { |sum, payment| sum + payment[:gross_pay_amount] }
  end
end
