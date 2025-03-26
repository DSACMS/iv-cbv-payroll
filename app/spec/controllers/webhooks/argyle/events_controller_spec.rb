require 'rails_helper'

RSpec.describe Webhooks::Argyle::EventsController, type: :controller do

  let(:argyle_service) { instance_double('ArgyleService') }
  let(:cbv_flow) { create(:cbv_flow, :with_argyle_account) }

  before do
    allow(controller).to receive(:set_argyle) { controller.instance_variable_set(:@argyle_service, argyle_service) }
    allow(controller).to receive(:authorize_webhook).and_return(true)
    allow(controller).to receive(:event_logger).and_return(double(track: true))
    allow(argyle_service).to receive(:verify_signature).and_return(true)
    allow(argyle_service).to receive(:get_supported_jobs).and_return(%w[identity paystubs gigs])
    allow(argyle_service).to receive(:get_webhook_event_outcome).and_return(:success)
    allow(argyle_service).to receive(:get_webhook_events).and_return(%w[users.fully_synced identities.added paystubs.fully_synced gigs.fully_synced accounts.connected])
  end

  describe 'POST #create' do

    context 'with accounts.connected webhook' do
      let(:webhook_payload) { create(:webhook_request, :argyle, event_type: "accounts.connected", cbv_flow: cbv_flow) }

      it 'creates a new payroll account' do
        expect {
          post :create, params: webhook_payload.payload
        }.to change(PayrollAccount, :count).by(1)

        expect(response).to have_http_status(:ok)

      end
    end

    context 'with users.fully_synced webhook' do
      let(:webhook_payload) { create(:webhook_request, :argyle, event_type: "users.fully_synced", cbv_flow: cbv_flow) }

      it 'creates a new payroll account' do
        expect {
          post :create, params: webhook_payload.payload
        }.to change(PayrollAccount, :count).by(1)

        expect(response).to have_http_status(:ok)

        payroll_account = PayrollAccount.last
        expect(payroll_account.type).to eq('argyle')
        expect(payroll_account.pinwheel_account_id).to eq(webhook_payload.payload.dig("data", "resource", "external_id"))
      end

      it 'creates a webhook event' do
        expect {
          post :create, params: webhook_payload.payload
        }.to change(WebhookEvent, :count).by(1)

        expect(WebhookEvent.last.event_name).to eq('users.fully_synced')
      end

      it 'tracks analytics' do
        expect(controller).to receive(:track_events)
        post :create, params: webhook_payload.payload
      end
    end

    context 'with gigs.fully_synced webhook' do
      let(:payroll_account) do
        create(:payroll_account, :argyle, cbv_flow: cbv_flow, type: 'PayrollAccount::Argyle')
      end

      let(:webhook_payload) do
        create(:webhook_request, :argyle,
          event_type: "gigs.fully_synced",
          cbv_flow: cbv_flow,
          account_id: payroll_account.pinwheel_account_id
        )
      end

      it 'creates a webhook event for the existing account' do
        expect {
          post :create, params: webhook_payload.payload
        }.to change(WebhookEvent, :count).by(1)

        expect(WebhookEvent.last.payroll_account).to eq(payroll_account)
        expect(WebhookEvent.last.event_name).to eq('gigs.fully_synced')
      end

      it 'tracks analytics when account is fully synced' do
        # First add some webhook events to make has_fully_synced? true
        create(:webhook_event, payroll_account: payroll_account, event_name: 'identities.added')
        create(:webhook_event, payroll_account: payroll_account, event_name: 'paystubs.added')

        expect(controller).to receive(:track_events)
        post :create, params: webhook_payload.payload
      end
    end
  end
end
