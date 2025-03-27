require 'rails_helper'

RSpec.describe Webhooks::Argyle::EventsController, type: :controller do

  let(:argyle_service) { class_double('ArgyleService') }
  let(:argyle_account_id) { SecureRandom.uuid }
  let(:argyle_user_id) { cbv_flow.end_user_id }
  let(:argyle_user_token) { 'argyle-token-456' }

  # Has highest priority for the let! block. It will be created before other let variables
  let!(:cbv_flow) do
    create(:cbv_flow, :with_argyle_account)
  end

  # In a runtime scenario- the web client would send a POST request to the /api/argyle/tokens
  # This does several things:
  #
  # 1. Retrieves the CbvFlow from the session
  # 2. Initializes Argyle in production or sandbox mode - depending on the agency configuration
  # 3. Creates an Argyle user which returns an Argyle user "id" and "user_token"
  # 4. Updates the CbvFlow with the Argyle user "id" and "user_token"
  # 5. Returns the "user_token" to the web client which can
  #    be used to create an Argyle "Link" or open the Argyle modal
  before do
    allow(controller).to receive(:set_argyle) { controller.instance_variable_set(:@argyle_service, argyle_service) }
    allow(controller).to receive(:authorize_webhook).and_return(true)
    allow(controller).to receive(:event_logger).and_return(double(track: true))
    allow(argyle_service).to receive(:verify_signature).and_return(true)
    allow(argyle_service).to receive(:get_webhook_event_jobs).and_return([])
    allow(argyle_service).to receive(:get_webhook_event_outcome).and_return(:success)
    allow(argyle_service).to receive(:get_supported_jobs).and_return(ArgyleService.get_supported_jobs)
    allow(argyle_service).to receive(:get_webhook_events).and_return(ArgyleService.get_webhook_events)
  end

  # Add a shared let definition for basic webhook request
  let(:create_webhook_request) do
    ->(event_type, options = {}) do
      create(
        :webhook_request,
        :argyle,
        event_type: event_type,
        argyle_account_id: options[:argyle_account_id] || argyle_account_id,
        argyle_user_id: options[:argyle_user_id] || argyle_user_id,
        cbv_flow: options[:cbv_flow] || cbv_flow,
        account_id: options[:account_id]
      ).payload
    end
  end

  describe 'POST #create' do

    context 'with accounts.connected webhook' do
      let(:webhook_request) { create_webhook_request.call("accounts.connected") }

      it 'creates a new payroll account' do
        expect {
          post :create, params: webhook_request
        }.to change(PayrollAccount, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with identities.added webhook' do
      let(:webhook_request) { create_webhook_request.call("identities.added") }

      it 'creates a new payroll account' do
        expect {
          post :create, params: webhook_request
        }.to change(PayrollAccount, :count).by(1)
      end
    end

    context 'with gigs.fully_synced webhook' do
      let(:payroll_account) do
        create(:payroll_account, :argyle, cbv_flow: cbv_flow, type: 'argyle')
      end

      let(:webhook_request) do
        create_webhook_request.call("gigs.fully_synced",
          account_id: payroll_account.pinwheel_account_id
        )
      end

      it 'tracks analytics when account is fully synced' do
        # First add some webhook events to make has_fully_synced? true
        create(:webhook_event, payroll_account: payroll_account, event_name: 'identities.added')
        create(:webhook_event, payroll_account: payroll_account, event_name: 'paystubs.fully_synced')

        expect(controller).to receive(:track_events)
        post :create, params: webhook_request
      end
    end

    context 'with all events successfully synced' do
      let(:account_connected_webhook) { create_webhook_request.call("accounts.connected") }
      let(:identities_added_webhook) { create_webhook_request.call("identities.added") }
      let(:paystubs_fully_synced_webhook) { create_webhook_request.call("paystubs.fully_synced") }
      let(:gigs_fully_synced_webhook) { create_webhook_request.call("gigs.fully_synced") }
      let(:users_fully_synced_webhook) { create_webhook_request.call("users.fully_synced") }

      it 'tracks analytics when account is fully synced' do
        expect(controller).to receive(:track_events)
        # after observing the webhook 
        post :create, params: account_connected_webhook
        post :create, params: identities_added_webhook
        post :create, params: users_fully_synced_webhook
        post :create, params: paystubs_fully_synced_webhook
        post :create, params: gigs_fully_synced_webhook

        # expect only one PayrollAccount to be created
        expect(PayrollAccount.count).to eq(1)
        expect(PayrollAccount.first.pinwheel_account_id).to eq(argyle_account_id)
        expect(PayrollAccount.first.cbv_flow).to eq(cbv_flow)
        
        # the PayrollAccount should have 5 webhook events
        expect(PayrollAccount.first.webhook_events.count).to eq(5)

        # the PayrollAccount should be considered fully synced
        expect(PayrollAccount.first.has_fully_synced?).to be_truthy
      end
    end
  end
end
