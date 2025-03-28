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
          created_at: seconds_since_invitation.seconds.ago,
          cbv_applicant_attributes: {
            case_number: "ABC1234"
          }
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

        cbv_flow = invitation.cbv_flows.first
        expect(cbv_flow).to have_attributes(
          cbv_applicant: have_attributes(case_number: "ABC1234"),
          cbv_flow_invitation: invitation
        )
      end

      it "sends events with metadata" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          cbv_flow_id: be_a(Integer),
          timestamp: be_a(Integer),
          invitation_id: invitation.id,
          client_agency_id: invitation.client_agency_id,
          seconds_since_invitation: seconds_since_invitation
        ))

        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantViewedAgreement", anything, hash_including(
          cbv_flow_id: be_a(Integer),
          timestamp: be_a(Integer),
          invitation_id: invitation.id,
          client_agency_id: invitation.client_agency_id
        ))

        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          cbv_flow_id: be_a(Integer),
          timestamp: be_a(Integer),
          invitation_id: invitation.id,
          client_agency_id: invitation.client_agency_id,
          seconds_since_invitation: seconds_since_invitation
        ))

        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantViewedAgreement", anything, hash_including(
          cbv_flow_id: be_a(Integer),
          timestamp: be_a(Integer),
          invitation_id: invitation.id
        ))

        get :show, params: { token: invitation.auth_token }
      end

      it "tracks CbvPageView events (from the base controller)" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("CbvPageView", anything, hash_including(
          user_agent: be_a(String),
          device_name: anything,
          device_type: be_a(String),
          browser: be_a(String),
          invitation_id: invitation.id,
          cbv_flow_id: be_a(Integer),
          client_agency_id: invitation.client_agency_id,
          path: "/cbv/entry"
        ))

        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("CbvPageView", anything, hash_including(
          user_agent: be_a(String),
          device_name: anything,
          device_type: be_a(String),
          browser: be_a(String),
          invitation_id: invitation.id,
          cbv_flow_id: be_a(Integer),
          client_agency_id: invitation.client_agency_id,
          path: "/cbv/entry"
        ))

        request.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        get :show, params: { token: invitation.auth_token }
      end

      it "tracks a CbvPageView event with Mixpanel (from the base controller)" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("CbvPageView", anything, hash_including(
          device_name: anything,
          device_type: be_a(String),
          browser: be_a(String),
          invitation_id: invitation.id,
          cbv_flow_id: be_a(Integer),
          client_agency_id: invitation.client_agency_id,
          path: "/cbv/entry"
        ))

        request.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        get :show, params: { token: invitation.auth_token }
      end

      context "when returning to an already-visited flow invitation" do
        let!(:existing_cbv_flow) { create(:cbv_flow, :invited, cbv_flow_invitation: invitation) }

        it "creates a new CbvFlow object" do
          get :show, params: { token: invitation.auth_token }

          expect(session[:cbv_flow_id]).not_to eq(existing_cbv_flow.id)
        end

        context "when the CbvFlow was already completed" do
          before do
            existing_cbv_flow.update(confirmation_code: "FOOBAR")
          end
          let!(:connected_account) do
            create(:payroll_account,
              cbv_flow: existing_cbv_flow,
              pinwheel_account_id: SecureRandom.uuid,
              created_at: 4.minutes.ago
            )
          end

          it "redirects to the expired invitation URL" do
            expect { get :show, params: { token: invitation.auth_token } }
              .not_to change { session[:cbv_flow_id] }

            expect(response).to redirect_to(cbv_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
          end
        end
      end

      context "when there is a CbvFlow from a different invitation in the session" do
        let(:other_invitation) { create(:cbv_flow_invitation) }
        let(:other_cbv_flow) { create(:cbv_flow, :invited, cbv_flow_invitation: other_invitation) }

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

          expect(response).to redirect_to(cbv_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
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
