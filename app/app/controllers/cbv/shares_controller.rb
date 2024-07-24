class Cbv::SharesController < Cbv::BaseController
  before_action :set_payments, only: %i[update]

  def show
  end

  def update
    if @cbv_flow.confirmation_code.blank?
      confirmation_code = generate_confirmation_code(@cbv_flow.site_id)
      @cbv_flow.update(confirmation_code: confirmation_code)
    end

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

  private

  def generate_confirmation_code(prefix = nil)
    [
      prefix,
      (Time.now.to_i % 36 ** 3).to_s(36).upcase.tr("OISB", "0158").rjust(3, "0"),
      @cbv_flow.id.to_s.rjust(4, "0")
    ].compact.join.upcase
  end
end
