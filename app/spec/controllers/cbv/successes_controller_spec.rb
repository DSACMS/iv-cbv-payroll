require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", site_id: "sandbox", confirmation_code: "NYC12345") }

    before do
      stub_request_end_user_paystubs_response
      stub_request_end_user_accounts_response
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "shows confirmation code in view" do
        get :show
        expect(response.body).to include(cbv_flow.confirmation_code)
      end
    end

    context "when confirmation_code is blank" do
      it "generates a new confirmation code" do
        expect(cbv_flow.confirmation_code).to be_blank
        put :update
        expect(cbv_flow.reload.confirmation_code).not_to be_blank
        expect(cbv_flow.reload.confirmation_code).to start_with("SANDBOX")
      end
    end

    context "when confirmation_code already exists" do
      let(:existing_confirmation_code) { "SANDBOX000" }

      before do
        cbv_flow.update(confirmation_code: existing_confirmation_code)
      end

      it "does not override the existing confirmation code" do
        expect(cbv_flow.reload.confirmation_code).to eq(existing_confirmation_code)
        expect { put :update }.not_to change { cbv_flow.reload.confirmation_code }
      end
    end

    context "when sending an email to the caseworker" do
      it "sends the email" do
        expect do
          post :update
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq("Applicant Income Verification: ABC1234")
      end

      it "stores the current time as transmitted_at" do
        expect { post :update }
          .to change { cbv_flow.reload.transmitted_at }
                .from(nil)
                .to(within(5.second).of(Time.now))
      end

      it "redirects to success screen" do
        post :update
        expect(response).to redirect_to({ controller: :successes, action: :show })
      end

      it "displays a notice" do
        post :update
        expect(flash[:notice]).to be_present
      end
    end
  end
end
