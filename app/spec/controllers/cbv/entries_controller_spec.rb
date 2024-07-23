require "rails_helper"

RSpec.describe Cbv::EntriesController do
  describe "#show" do
    render_views

    it "renders properly" do
      get :show

      expect(response).to be_successful
    end

    it "sets a CbvFlow object in the session" do
      expect { get :show }
        .to change { session[:cbv_flow_id] }
              .from(nil)
              .to(be_an(Integer))
    end

    context "when following a link from a flow invitation" do
      let(:invitation) { CbvFlowInvitation.create(case_number: "ABC1234", site_id: "nyc") }

      it "sets a CbvFlow object based on the invitation" do
        expect { get :show, params: { token: invitation.auth_token } }
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
        let(:existing_cbv_flow) { CbvFlow.create(case_number: "ABC1234", cbv_flow_invitation: invitation, site_id: "nyc") }

        it "uses the existing CbvFlow object" do
          expect { get :show, params: { token: invitation.auth_token } }
            .to change { session[:cbv_flow_id] }
                  .from(nil)
                  .to(existing_cbv_flow.id)
        end
      end

      context "when there is already a CbvFlow in the session" do
        let(:other_cbv_flow) { CbvFlow.create(case_number: "ZZZ0000", site_id: "nyc") }

        before do
          session[:cbv_flow_id] = other_cbv_flow.id
        end

        it "replaces the session's CbvFlow id with the one from the link token" do
          expect { get :show, params: { token: invitation.auth_token } }
            .to change { session[:cbv_flow_id] }
                  .from(other_cbv_flow.id)
                  .to(be_an(Integer))
        end
      end

      context "when the token is invalid" do
        it "redirects to the homepage" do
          expect { get :show, params: { token: "some-invalid-token" } }
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
        get :show

        expect(response).to redirect_to(root_url)
      end
    end
  end
end
