require 'rails_helper'

RSpec.describe Api::LoadTestSessionsController, type: :controller do
  describe "POST #create" do
    context "environment restrictions" do
      it "allows access in test environment" do
        post :create
        expect(response).not_to have_http_status(:forbidden)
      end

      it "denies access in production environment" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("production.example.com")

        post :create

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq({
          "error" => "This endpoint is only available in non-production environments"
        })
      end

      it "allows access in demo environment" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("demo.divt.app")

        post :create

        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:created)
      end

      it "allows access in Arizona demo environment" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("az.demo.divt.app")

        post :create

        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:created)
      end

      it "allows access in Pennsylvania demo environment" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("pa.demo.divt.app")

        post :create

        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:created)
      end

      it "deny access to changed non-matching TLDs" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("demo.divt.app.fake.tld")

        post :create

        expect(response).to have_http_status(:forbidden)
        expect(response).not_to have_http_status(:created)
      end

      it "deny access to fake url" do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DOMAIN_NAME").and_return("pa.demo.not-divt.app")

        post :create

        expect(response).to have_http_status(:forbidden)
        expect(response).not_to have_http_status(:created)
      end
    end

    context "with valid parameters" do
      context "synced scenario" do
        let(:params) { { client_agency_id: "sandbox", scenario: "synced" } }

        it "creates a CBV flow with applicant" do
          expect {
            post :create, params: params
          }.to change(CbvFlow, :count).by(1)
           .and change(CbvApplicant, :count).by(1)

          cbv_flow = CbvFlow.last
          expect(cbv_flow.client_agency_id).to eq("sandbox")
          expect(cbv_flow.cbv_applicant).to be_present
          expect(cbv_flow.consented_to_authorized_use_at).to be_present
        end

        it "creates a fully synced payroll account" do
          expect {
            post :create, params: params
          }.to change(PayrollAccount::Argyle, :count).by(1)

          payroll_account = PayrollAccount::Argyle.last
          expect(payroll_account.aggregator_account_id).to eq("019571bc-2f60-3955-d972-dbadfe0913a8")
          expect(payroll_account.synchronization_status).to eq("succeeded")
          expect(payroll_account.supported_jobs).to match_array(%w[accounts income paystubs employment identity])
        end

        it "creates successful webhook events" do
          expect {
            post :create, params: params
          }.to change(WebhookEvent, :count).by(3)

          webhook_events = WebhookEvent.last(3)
          expect(webhook_events.map(&:event_name)).to match_array([
            "accounts.connected",
            "identities.added",
            "paystubs.fully_synced"
          ])
          expect(webhook_events.map(&:event_outcome)).to all(eq("success"))
        end

        it "sets the session cookie" do
          post :create, params: params

          expect(session[:cbv_flow_id]).to eq(CbvFlow.last.id)
        end

        it "returns success response with flow details" do
          post :create, params: params

          expect(response).to have_http_status(:created)

          json_response = JSON.parse(response.body)
          expect(json_response["success"]).to eq(true)
          expect(json_response["cbv_flow_id"]).to eq(CbvFlow.last.id)
          expect(json_response["account_id"]).to eq("019571bc-2f60-3955-d972-dbadfe0913a8")
          expect(json_response["client_agency_id"]).to eq("sandbox")
          expect(json_response["scenario"]).to eq("synced")
          expect(json_response["csrf_token"]).to be_present
          expect(json_response["message"]).to eq("Session created. Cookie will be set in Set-Cookie header.")
        end
      end

      context "pending scenario" do
        let(:params) { { client_agency_id: "sandbox", scenario: "pending" } }

        it "creates a CBV flow with applicant" do
          expect {
            post :create, params: params
          }.to change(CbvFlow, :count).by(1)
           .and change(CbvApplicant, :count).by(1)
        end

        it "creates a pending payroll account" do
          expect {
            post :create, params: params
          }.to change(PayrollAccount::Argyle, :count).by(1)

          payroll_account = PayrollAccount::Argyle.last
          expect(payroll_account.synchronization_status).to eq("in_progress")
          expect(payroll_account.supported_jobs).to match_array(%w[accounts income paystubs employment identity])
        end

        it "creates initial webhook event" do
          expect {
            post :create, params: params
          }.to change(WebhookEvent, :count).by(1)

          webhook_event = WebhookEvent.last
          expect(webhook_event.event_name).to eq("accounts.connected")
          expect(webhook_event.event_outcome).to eq("success")
        end

        it "returns success response" do
          post :create, params: params

          expect(response).to have_http_status(:created)

          json_response = JSON.parse(response.body)
          expect(json_response["success"]).to eq(true)
          expect(json_response["scenario"]).to eq("pending")
        end
      end

      context "failed scenario" do
        let(:params) { { client_agency_id: "sandbox", scenario: "failed" } }

        it "creates a CBV flow with applicant" do
          expect {
            post :create, params: params
          }.to change(CbvFlow, :count).by(1)
           .and change(CbvApplicant, :count).by(1)
        end

        it "creates a failed payroll account" do
          expect {
            post :create, params: params
          }.to change(PayrollAccount::Argyle, :count).by(1)

          payroll_account = PayrollAccount::Argyle.last
          expect(payroll_account.synchronization_status).to eq("failed")
          expect(payroll_account.supported_jobs).to match_array(%w[accounts income paystubs employment identity])
        end

        it "creates webhook events with failure" do
          expect {
            post :create, params: params
          }.to change(WebhookEvent, :count).by(2)

          webhook_events = WebhookEvent.last(2)
          expect(webhook_events.map(&:event_name)).to match_array([
            "accounts.connected",
            "paystubs.fully_synced"
          ])

          success_event = webhook_events.find { |e| e.event_name == "accounts.connected" }
          error_event = webhook_events.find { |e| e.event_name == "paystubs.fully_synced" }

          expect(success_event.event_outcome).to eq("success")
          expect(error_event.event_outcome).to eq("error")
        end

        it "returns success response" do
          post :create, params: params

          expect(response).to have_http_status(:created)

          json_response = JSON.parse(response.body)
          expect(json_response["success"]).to eq(true)
          expect(json_response["scenario"]).to eq("failed")
        end
      end
    end

    context "with default parameters" do
      it "defaults to sandbox client_agency_id when not provided" do
        post :create

        json_response = JSON.parse(response.body)
        expect(json_response["client_agency_id"]).to eq("sandbox")
      end

      it "defaults to synced scenario when not provided" do
        post :create

        json_response = JSON.parse(response.body)
        expect(json_response["scenario"]).to eq("synced")
      end
    end

    context "with invalid parameters" do
      context "invalid client_agency_id" do
        let(:params) { { client_agency_id: "invalid_agency" } }

        it "returns unprocessable_entity status" do
          post :create, params: params

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error message" do
          post :create, params: params

          json_response = JSON.parse(response.body)
          expect(json_response["error"]).to eq("Invalid client_agency_id")
        end

        it "does not create any records" do
          expect {
            post :create, params: params
          }.not_to change(CbvFlow, :count)
        end
      end

      context "invalid scenario" do
        let(:params) { { scenario: "invalid_scenario" } }

        it "returns unprocessable_entity status" do
          post :create, params: params

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error message with scenario name" do
          post :create, params: params

          json_response = JSON.parse(response.body)
          expect(json_response["error"]).to eq("Invalid scenario: invalid_scenario")
        end

        it "does not create any records" do
          expect {
            post :create, params: params
          }.not_to change(CbvFlow, :count)
        end
      end
    end

    context "CSRF protection" do
      it "skips forgery protection" do
        # This test verifies that skip_forgery_protection is working
        # by making a request without CSRF token and expecting success
        post :create, params: { client_agency_id: "sandbox", scenario: "synced" }

        expect(response).to have_http_status(:created)
      end

      it "includes CSRF token in response" do
        post :create

        json_response = JSON.parse(response.body)
        expect(json_response["csrf_token"]).to be_present
        expect(json_response["csrf_token"]).to be_a(String)
      end
    end

    context "multiple requests" do
      it "creates independent sessions for each request" do
        post :create, params: { scenario: "synced" }
        first_cbv_flow_id = JSON.parse(response.body)["cbv_flow_id"]

        post :create, params: { scenario: "pending" }
        second_cbv_flow_id = JSON.parse(response.body)["cbv_flow_id"]

        expect(first_cbv_flow_id).not_to eq(second_cbv_flow_id)
        expect(CbvFlow.count).to eq(2)
      end

      it "overwrites session with latest cbv_flow_id" do
        post :create, params: { scenario: "synced" }
        first_cbv_flow_id = JSON.parse(response.body)["cbv_flow_id"]

        post :create, params: { scenario: "pending" }
        second_cbv_flow_id = JSON.parse(response.body)["cbv_flow_id"]

        expect(session[:cbv_flow_id]).to eq(second_cbv_flow_id)
        expect(session[:cbv_flow_id]).not_to eq(first_cbv_flow_id)
      end
    end
  end
end
