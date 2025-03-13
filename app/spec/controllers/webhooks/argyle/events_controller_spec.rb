require 'rails_helper'

RSpec.describe Webhooks::Argyle::EventsController, type: :controller do
  # Test helper for generating webhook payloads
  def generate_argyle_webhook(event_type, options = {})
    user_id = options[:user_id] || SecureRandom.uuid
    account_id = options[:account_id] || SecureRandom.uuid

    case event_type
    when 'accounts.connected'
      {
        event: event_type,
        name: "test_webhook",
        data: {
          user: user_id,
          resource: {
            id: account_id,
            connection: {
              status: options[:status] || "connected"
            },
            providers_connected: [ options[:provider] || "Sample Provider" ]
          }
        }
      }
    when 'gigs.fully_synced'
      {
        event: event_type,
        name: "test_webhook",
        data: {
          account: account_id,
          user: user_id,
          available_from: options[:from] || (Date.today - 365).iso8601,
          available_to: options[:to] || Date.today.iso8601,
          available_count: options[:count] || 150
        }
      }
    else
      {
        event: event_type,
        name: "test_webhook",
        data: {
          user: user_id,
          resource: {
            id: account_id
          }
        }
      }
    end
  end

  let(:cbv_flow) { create(:cbv_flow) }
  let(:argyle_service) { instance_double('ArgyleService') }

  before do
    allow(controller).to receive(:set_cbv_flow) { controller.instance_variable_set(:@cbv_flow, cbv_flow) }
    allow(controller).to receive(:set_argyle) { controller.instance_variable_set(:@argyle, argyle_service) }
    allow(controller).to receive(:authorize_webhook).and_return(true)
    allow(argyle_service).to receive(:verify_signature).and_return(true)
    allow(controller).to receive(:event_logger).and_return(double(track: true))
  end

  describe 'POST #create' do
    context 'with accounts.connected webhook' do
      let(:webhook_payload) { generate_argyle_webhook('accounts.connected') }

      it 'creates a new payroll account' do
        expect {
          post :create, params: webhook_payload
        }.to change(PayrollAccount, :count).by(1)

        expect(response).to have_http_status(:ok)

        payroll_account = PayrollAccount.last
        expect(payroll_account.type).to eq('argyle')
        expect(payroll_account.pinwheel_account_id).to eq(webhook_payload[:data][:resource][:id])
      end

      it 'creates a webhook event' do
        expect {
          post :create, params: webhook_payload
        }.to change(WebhookEvent, :count).by(1)

        expect(WebhookEvent.last.event_name).to eq('accounts.connected')
      end

      it 'tracks analytics' do
        expect(controller).to receive(:track_events)
        post :create, params: webhook_payload
      end
    end

    context 'with gigs.fully_synced webhook' do
      let(:payroll_account) do
        create(:payroll_account, :argyle, cbv_flow: cbv_flow, type: 'PayrollAccount::Argyle')
      end

      let(:webhook_payload) do
        generate_argyle_webhook('gigs.fully_synced', account_id: payroll_account.pinwheel_account_id)
      end

      it 'creates a webhook event for the existing account' do
        expect {
          post :create, params: webhook_payload
        }.to change(WebhookEvent, :count).by(1)

        expect(WebhookEvent.last.payroll_account).to eq(payroll_account)
        expect(WebhookEvent.last.event_name).to eq('gigs.fully_synced')
      end

      it 'tracks analytics when account is fully synced' do
        # First add some webhook events to make has_fully_synced? true
        create(:webhook_event, payroll_account: payroll_account, event_name: 'identities.added')
        create(:webhook_event, payroll_account: payroll_account, event_name: 'paystubs.added')

        expect(controller).to receive(:track_events)
        post :create, params: webhook_payload
      end

      it 'updates synchronization page' do
        expect(controller).to receive(:update_synchronization_page)
        post :create, params: webhook_payload
      end
    end

    context 'in test environment' do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
      end

      it 'records webhook payload to file' do
        webhook_payload = generate_argyle_webhook('accounts.connected')

        expect(FileUtils).to receive(:mkdir_p)
        expect(File).to receive(:write).with(anything, anything)

        post :create, params: webhook_payload
      end
    end
  end
end
