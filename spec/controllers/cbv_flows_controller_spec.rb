require "rails_helper"

RSpec.describe CbvFlowsController do
  include ArgyleApiHelper

  around do |ex|
    stub_environment_variable("ARGYLE_API_TOKEN", "foobar", &ex)
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

      context "when the token is invalid" do
        it "redirects to the homepage" do
          expect { get :entry, params: { token: "some-invalid-token" } }
            .not_to change { session[:cbv_flow_id] }

          expect(response).to redirect_to(root_url)
        end
      end
    end
  end

  describe "#employer_search" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234") }

    let(:argyle_user_id) { "abc-def-ghi" }

    let(:user_token) { "foobar" }

    let(:argyle_mock_items_response) do
      {
        results: [
          {
            id: 'item_000002102',
            name: 'ACME'
          }
        ]
      }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_items_response
      stub_create_user_response(user_id: argyle_user_id)
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :employer_search
        expect(response).to be_successful
      end
    end

    context "when the user does not have an Argyle token" do
      it "requests a new token from Argyle" do
        get :employer_search
        expect(response).to be_ok
      end

      it "saves the token in the CbvFlow model" do
        expect { get :employer_search }
          .to change { cbv_flow.reload.argyle_user_id }
          .from(nil)
          .to(argyle_user_id)
      end
    end

    context "when the user already has an Argyle token in their session" do
      before do
        session[:argyle_user_token] = user_token
      end

      it "does not request a new User Token from Argyle" do
        get :employer_search
        expect(response).to be_ok
      end
    end
  end

  describe "#summary" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_paystubs_response
    end

    it "renders properly" do
      get :summary
      expect(response).to be_successful
    end
  end
end
