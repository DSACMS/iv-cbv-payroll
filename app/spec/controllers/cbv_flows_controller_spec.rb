require "rails_helper"

RSpec.describe CbvFlowsController do
  include PinwheelApiHelper

  around do |ex|
    stub_environment_variable("PINWHEEL_API_TOKEN", "foobar", &ex)
  end

  describe "#entry" do
    render_views

    it "renders properly" do
      get :entry

      expect(response).to be_successful
    end

    it "sets a CbvFlow object in the session" do
      expect { get :entry }
        .to change { session[:cbv_flow_id] }
              .from(nil)
              .to(be_an(Integer))
    end

    context "when following a link from a flow invitation" do
      let(:invitation) { CbvFlowInvitation.create(case_number: "ABC1234") }

      it "sets a CbvFlow object based on the invitation" do
        expect { get :entry, params: { token: invitation.auth_token } }
          .to change { session[:cbv_flow_id] }
                .from(nil)
                .to(be_an(Integer))

        cbv_flow = CbvFlow.find(session[:cbv_flow_id])
        expect(cbv_flow).to have_attributes(
                              case_number: "ABC1234",
                              cbv_flow_invitation: invitation
                            )
      end

      context "when returning to an already-visited flow invitation" do
        let(:existing_cbv_flow) { CbvFlow.create(case_number: "ABC1234", cbv_flow_invitation: invitation) }

        it "uses the existing CbvFlow object" do
          expect { get :entry, params: { token: invitation.auth_token } }
            .to change { session[:cbv_flow_id] }
                  .from(nil)
                  .to(existing_cbv_flow.id)
        end
      end

      context "when there is already a CbvFlow in the session" do
        let(:other_cbv_flow) { CbvFlow.create(case_number: "ZZZ0000") }

        before do
          session[:cbv_flow_id] = other_cbv_flow.id
        end

        it "replaces the session's CbvFlow id with the one from the link token" do
          expect { get :entry, params: { token: invitation.auth_token } }
            .to change { session[:cbv_flow_id] }
                  .from(other_cbv_flow.id)
                  .to(be_an(Integer))
        end
      end

      context "when the token is invalid" do
        it "redirects to the homepage" do
          expect { get :entry, params: { token: "some-invalid-token" } }
            .not_to change { session[:cbv_flow_id] }

          expect(response).to redirect_to(root_url)
        end
      end
    end

    context "when the session points to a deleted cbv flow" do
      before do
        session[:cbv_flow_id] = -1
      end

      it "uses the existing CbvFlow object" do
        get :entry

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe "#employer_search" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234") }

    let(:pinwheel_token_id) { "abc-def-ghi" }

    let(:user_token) { "foobar" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :employer_search
        expect(response).to be_successful
      end
    end

    context "when the user does not have a Pinwheel token" do
      skip "requests a new token from Pinwheel" do
        get :employer_search
        expect(response).to be_ok
      end

      skip "saves the token in the CbvFlow model" do
        expect { get :employer_search }
          .to change { cbv_flow.reload.pinwheel_token_id }
                .from(nil)
                .to(pinwheel_token_id)
      end
    end
  end

  describe "#summary" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
    end

    skip "renders properly" do
      get :summary
      expect(response).to be_successful
    end

    context "when saving additional information for the caseworker" do
      let(:additional_information) { "This is some additional information for the caseworker" }

      it "saves and redirects to the next page" do
        expect do
          patch :summary, params: { cbv_flow: { additional_information: additional_information } }
        end.to change { cbv_flow.reload.additional_information }
                 .from(nil)
                 .to(additional_information)

        expect(response).to redirect_to(cbv_flow_share_path)
      end
    end
  end

  describe "#share" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_paystubs_response
      stub_request_end_user_accounts_response
    end

    it "renders" do
      get :share
      expect(response).to be_successful
    end

    context "when sending an email to the caseworker" do
      let(:email_address) { "test@example.com" }

      it "sends the email" do
        expect do
          post :share
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to eq([email_address])
        expect(email.subject).to eq("Applicant Income Verification: ABC1234")
      end
    end
  end
end
