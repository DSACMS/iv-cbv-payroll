require "rails_helper"

RSpec.describe Cbv::EntriesController do
  describe "#show" do
    render_views

    it "redirects the user back to the homepage" do
      expect { get :show }
        .not_to change { session[:cbv_flow_id] }
      expect(response).to redirect_to(root_url)
    end

    context "when following a link from a flow invitation" do
      let(:seconds_since_invitation) { 300 }
      let(:invitation) do
        create(
          :cbv_flow_invitation,
          case_number: "ABC1234",
          created_at: seconds_since_invitation.seconds.ago
        )
      end

      around do |ex|
        Timecop.freeze(&ex)
      end

      it "renders properly" do
        get :show, params: { token: invitation.auth_token }

        expect(response).to be_successful
      end

      it "sets a CbvFlow object based on the invitation" do
        expect { get :show, params: { token: invitation.auth_token } }
          .to change { session[:cbv_flow_id] }
                .from(nil)
                .to(be_an(Integer))

        cbv_flow = invitation.cbv_flow
        expect(cbv_flow).to have_attributes(
          case_number: "ABC1234",
          cbv_flow_invitation: invitation
        )
      end

      it "sends a NewRelic event with metadata" do
        allow(NewRelicEventTracker).to receive(:track)

        get :show, params: { token: invitation.auth_token }
        cbv_flow = invitation.cbv_flow

        expect(NewRelicEventTracker).to have_received(:track).with("ClickedCBVInvitationLink", {
          timestamp: be_a(Integer),
          invitation_id: invitation.id,
          cbv_flow_id: cbv_flow.id,
          site_id: invitation.site_id,
          seconds_since_invitation: seconds_since_invitation
        })
      end

      context "when returning to an already-visited flow invitation" do
        let(:existing_cbv_flow) { create(:cbv_flow, cbv_flow_invitation: invitation) }

        it "uses the existing CbvFlow object" do
          expect { get :show, params: { token: invitation.auth_token } }
            .to change { session[:cbv_flow_id] }
                  .from(nil)
                  .to(existing_cbv_flow.id)
        end

        context "when the CbvFlow has already linked a employer/employers" do
          let!(:older_connected_account) do
            create(:pinwheel_account,
              cbv_flow: existing_cbv_flow,
              pinwheel_account_id: SecureRandom.uuid,
              created_at: 15.minutes.ago
            )
          end
          let!(:connected_account) do
            create(:pinwheel_account,
              cbv_flow: existing_cbv_flow,
              pinwheel_account_id: SecureRandom.uuid,
              created_at: 4.minutes.ago
            )
          end

          it "redirects to the payment details page for the more recently linked employer" do
            expect { get :show, params: { token: invitation.auth_token } }
              .to change { session[:cbv_flow_id] }
              .from(nil)
              .to(existing_cbv_flow.id)

            expect(response).to redirect_to(
              cbv_flow_payment_details_path(user: { account_id: connected_account.pinwheel_account_id })
            )
          end
        end

        context "when the CbvFlow was already completed" do
          before do
            existing_cbv_flow.update(confirmation_code: "FOOBAR")
          end
          let!(:connected_account) do
            create(:pinwheel_account,
              cbv_flow: existing_cbv_flow,
              pinwheel_account_id: SecureRandom.uuid,
              created_at: 4.minutes.ago
            )
          end

          it "redirects to the expired invitation URL" do
            expect { get :show, params: { token: invitation.auth_token } }
              .not_to change { session[:cbv_flow_id] }

            expect(response).to redirect_to(cbv_flow_expired_invitation_path)
          end
        end
      end

      context "when there is already a CbvFlow in the session" do
        let(:other_cbv_flow) { create(:cbv_flow, case_number: "ZZZ0000", site_id: "sandbox") }

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

      context "when the invitation is expired" do
        before do
          allow_any_instance_of(CbvFlowInvitation)
            .to receive(:expired?)
            .and_return(true)
        end

        it "redirects to the expired invitations page" do
          expect { get :show, params: { token: invitation.auth_token } }
            .not_to change { session[:cbv_flow_id] }

          expect(response).to redirect_to(cbv_flow_expired_invitation_path)
        end
      end
    end

    context "when the session points to a deleted cbv flow" do
      before do
        session[:cbv_flow_id] = -1
      end

      it "redirects to the homepage" do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end
  end
end
