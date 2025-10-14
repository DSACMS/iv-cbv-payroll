class Api::LoadTestSessionsController < ApplicationController
  include NonProductionAccessible

  skip_forgery_protection

  # Only allow in non-production environments (development/test/demo)
  before_action :ensure_non_production_environment

  def create
    client_agency_id = params[:client_agency_id] || "sandbox"
    scenario = params[:scenario] || "synced"

    # Validate client_agency_id
    unless Rails.application.config.client_agencies.client_agency_ids.include?(client_agency_id)
      return render json: { error: "Invalid client_agency_id" }, status: :unprocessable_entity
    end

    # Create test data based on scenario
    cbv_flow, account_id = case scenario
                           when "synced"
                             create_synced_flow(client_agency_id)
                           when "pending"
                             create_pending_flow(client_agency_id)
                           when "failed"
                             create_failed_flow(client_agency_id)
                           else
                             return render json: { error: "Invalid scenario: #{scenario}" }, status: :unprocessable_entity
                           end

    # Set session using Rails' session mechanism (Rails will encrypt the cookie)
    session[:cbv_flow_id] = cbv_flow.id

    render json: {
      success: true,
      cbv_flow_id: cbv_flow.id,
      account_id: account_id,
      client_agency_id: client_agency_id,
      scenario: scenario,
      csrf_token: form_authenticity_token,
      message: "Session created. Cookie will be set in Set-Cookie header."
    }, status: :created
  end

  private

  def argyle_account_id
    # hard coded to bob's id to match the mock api service
    "019571bc-2f60-3955-d972-dbadfe0913a8"
  end

  def ensure_non_production_environment
    unless is_not_production?
      render json: { error: "This endpoint is only available in non-production environments" }, status: :forbidden
    end
  end

  def create_synced_flow(client_agency_id)
    cbv_applicant = CbvApplicant.create!(client_agency_id: client_agency_id)
    cbv_flow = CbvFlow.create!(
      client_agency_id: client_agency_id,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: Time.current
    )

    # Create fully synced payroll account
    payroll_account = PayrollAccount::Argyle.create!(
      cbv_flow: cbv_flow,
      aggregator_account_id: argyle_account_id,
      pinwheel_account_id: argyle_account_id,
      supported_jobs: %w[accounts income paystubs employment identity],
      synchronization_status: :succeeded
    )

    # Create successful webhook events matching Argyle's actual event names
    # See: Aggregators::Webhooks::Argyle::SUBSCRIBED_WEBHOOK_EVENTS
    [
      { event_name: "accounts.connected", event_outcome: "success" },       # accounts job
      { event_name: "identities.added", event_outcome: "success" },        # identity + income jobs
      { event_name: "paystubs.fully_synced", event_outcome: "success" }    # paystubs + employment jobs
    ].each do |event|
      WebhookEvent.create!(
        payroll_account: payroll_account,
        event_name: event[:event_name],
        event_outcome: event[:event_outcome]
      )
    end

    [ cbv_flow, argyle_account_id ]
  end

  def create_pending_flow(client_agency_id)
    cbv_applicant = CbvApplicant.create!(client_agency_id: client_agency_id)
    cbv_flow = CbvFlow.create!(
      client_agency_id: client_agency_id,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: Time.current
    )

    # Create pending payroll account
    payroll_account = PayrollAccount::Argyle.create!(
      cbv_flow: cbv_flow,
      pinwheel_account_id: argyle_account_id,
      aggregator_account_id: argyle_account_id,
      supported_jobs: %w[accounts income paystubs employment identity],
      synchronization_status: :in_progress
    )

    # Create initial webhook event (account connected, but sync still in progress)
    WebhookEvent.create!(
      payroll_account: payroll_account,
      event_name: "accounts.connected",
      event_outcome: "success"
    )

    [ cbv_flow, argyle_account_id ]
  end

  def create_failed_flow(client_agency_id)
    cbv_applicant = CbvApplicant.create!(client_agency_id: client_agency_id)
    cbv_flow = CbvFlow.create!(
      client_agency_id: client_agency_id,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: Time.current
    )

    # Create failed payroll account
    payroll_account = PayrollAccount::Argyle.create!(
      cbv_flow: cbv_flow,
      pinwheel_account_id: argyle_account_id,
      aggregator_account_id: argyle_account_id,
      supported_jobs: %w[accounts income paystubs employment identity],
      synchronization_status: :failed
    )

    # Create failed webhook events - paystubs job failed
    [
      { event_name: "accounts.connected", event_outcome: "success" },
      { event_name: "paystubs.fully_synced", event_outcome: "error" }  # This marks paystubs/employment as failed
    ].each do |event|
      WebhookEvent.create!(
        payroll_account: payroll_account,
        event_name: event[:event_name],
        event_outcome: event[:event_outcome]
      )
    end

    [ cbv_flow, argyle_account_id ]
  end
end
