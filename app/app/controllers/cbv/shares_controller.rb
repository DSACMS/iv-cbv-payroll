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

    redirect_to({ controller: :successes, action: :show }, flash: { notice: t(".successfully_shared_to_caseworker") })
  end
end
