class Webhooks::Pinwheel::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_pinwheel, :authorize_webhook
  skip_before_action :verify_authenticity_token

  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create
    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for end_user_id: #{params["payload"]["end_user_id"]}"
      return render json: { status: "ok" }
    end

    if params["event"] == "account.added"
      PayrollAccount
        .create_with(cbv_flow: @cbv_flow)
        .find_or_create_by(pinwheel_account_id: params["payload"]["account_id"])
      track_account_created_event(@cbv_flow, params["payload"]["platform_name"])
    end

    if PayrollAccount::Pinwheel::EVENTS_MAP.keys.include?(params["event"])
      pinwheel_account = PayrollAccount.find_by_pinwheel_account_id(params["payload"]["account_id"])

      if pinwheel_account.present?
        pinwheel_account.update!(PayrollAccount::Pinwheel::EVENTS_MAP[params["event"]] => Time.now)

        if params.dig("payload", "outcome") == "error" || params.dig("payload", "outcome") == "pending"
          pinwheel_account.update!(PayrollAccount::Pinwheel::EVENTS_ERRORS_MAP[params["event"]] => Time.now)
        end

        if pinwheel_account.has_fully_synced?
          track_account_synced_event(@cbv_flow, pinwheel_account)

          PaystubsChannel.broadcast_to(@cbv_flow, {
            event: "cbv.status_update",
            account_id: params["payload"]["account_id"],
            has_fully_synced: true
          })
        end
      end
    end
  end

  private

  def authorize_webhook
    # To prevent timing attacks, we attempt to verify the webhook signature
    # using a same-length DUMMY_API_KEY even if the `end_user_id` does not
    # match a valid `cbv_flow`.

    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    digest = @pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless @pinwheel.verify_signature(signature, digest)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def track_account_synced_event(cbv_flow, pinwheel_account)
    event_logger.track("ApplicantFinishedPinwheelSync", request, {
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      identity_success: pinwheel_account.job_succeeded?("identity"),
      identity_supported: pinwheel_account.supported_jobs.include?("identity"),
      income_success: pinwheel_account.job_succeeded?("income"),
      income_supported: pinwheel_account.supported_jobs.include?("income"),
      paystubs_success: pinwheel_account.job_succeeded?("paystubs"),
      paystubs_supported: pinwheel_account.supported_jobs.include?("paystubs"),
      employment_success: pinwheel_account.job_succeeded?("employment"),
      employment_supported: pinwheel_account.supported_jobs.include?("employment"),
      sync_duration_seconds: Time.now - pinwheel_account.created_at
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantFinishedPinwheelSync): #{ex}"
  end

  def track_account_created_event(cbv_flow, platform_name)
    event_logger.track("ApplicantCreatedPinwheelAccount", request, {
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      invitation_id: cbv_flow.cbv_flow_invitation_id,
      platform_name: platform_name
    })
  end

  def set_cbv_flow
    @cbv_flow = CbvFlow.find_by_end_user_id(params["payload"]["end_user_id"])
  end

  def set_pinwheel
    @pinwheel = @cbv_flow.present? ? pinwheel_for(@cbv_flow) : PinwheelService.new("sandbox", DUMMY_API_KEY)
  end
end
