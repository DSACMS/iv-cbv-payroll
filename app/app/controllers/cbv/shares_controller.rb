class Cbv::SharesController < Cbv::BaseController
  before_action :set_payments, only: %i[update]

  def show
  end

  def update
    email_address = ENV["SLACK_TEST_EMAIL"]
    ApplicantMailer.with(
      email_address: email_address,
      cbv_flow: @cbv_flow,
      payments: @payments
    ).caseworker_summary_email.deliver_now

    NewRelicEventTracker.track("IncomeSummarySharedWithCaseworker", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id
    })
    redirect_to({ controller: :successes, action: :show }, flash: { notice: t(".successfully_shared_to_caseworker") })
  end
end
