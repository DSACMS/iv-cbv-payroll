require "rails_helper"

RSpec.describe Activities::EntriesController do
  include_context "activity_hub"

  let(:flow) { create(:activity_flow) }

  render_views

  describe '#show' do
    context "with generic link" do
      it 'sets session flow type and id' do
        get :show, params: { client_agency_id: 'sandbox' }
        expect(session[:flow_type]).to eq(:activity)
        expect(session[:flow_id]).to be_present
      end

      context 'when a previous flow exists for the same device' do
        before do
          cookies.permanent.signed[:device_id] = "test-device-id"
          create(:activity_flow, cbv_applicant: flow.cbv_applicant, device_id: "test-device-id")
        end

        it "creates a new applicant" do
          expect {
            get :show, params: { client_agency_id: 'sandbox' }
          }.to change(CbvApplicant, :count).by(1)

          expect(session[:flow_type]).to eq(:activity)
          expect(session[:flow_id]).to be_truthy
        end
      end

      context "when no previous flow exists for the device" do
        it "creates a new activity flow and sets it in the session" do
          request.host = ENV["SANDBOX_DOMAIN_NAME"]

          expect {
            get :show
          }.to change(ActivityFlow, :count).by(1)
            .and change(CbvApplicant, :count).by(1)

          expect(session[:flow_id]).to be_present
          flow = ActivityFlow.find(session[:flow_id])
          expect(flow.cbv_applicant_id).to be_present
          expect(flow.cbv_applicant).to be_persisted
          expect(flow.cbv_applicant.client_agency_id).to eq("sandbox")
        end

        context "when accessing via incorrect subdomain" do
          it "redirects to 404 page when domain doesn't match any agency" do
            request.host = "sandbox.localhost"

            get :show

            expect(response).to redirect_to("/404")
          end
        end
      end
    end

    context "with tokenized link" do
      let(:invitation) { create(:activity_flow_invitation) }

      it "creates a flow from the invitation and sets session" do
        get :show, params: { token: invitation.auth_token }

        expect(session[:flow_type]).to eq(:activity)
        expect(session[:flow_id]).to be_present
        expect(ActivityFlow.find(session[:flow_id]).activity_flow_invitation).to eq(invitation)
      end

      it "redirects to root with error for invalid token" do
        get :show, params: { token: "invalid_token" }

        expect(response).to redirect_to(root_url)
        expect(flash[:alert]).to eq(I18n.t("activities.errors.invalid_token"))
      end
    end
  end

  describe "activity hub access control" do
    it "allows access when ACTIVITY_HUB_ENABLED is true" do
      get :show, params: { client_agency_id: "sandbox" }

      expect(response).not_to redirect_to(root_url)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is not set" do
      stub_environment_variable("ACTIVITY_HUB_ENABLED", nil) do
        get :show, params: { client_agency_id: "sandbox" }
      end

      expect(response).to redirect_to(root_url)
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is false" do
      stub_environment_variable("ACTIVITY_HUB_ENABLED", "false") do
        get :show, params: { client_agency_id: "sandbox" }
      end

      expect(response).to redirect_to(root_url)
    end
  end

  describe "employment focused entry page" do
    context "when the flow is employment_focused" do
      let(:invitation) { create(:activity_flow_invitation, employment_focused: true) }

      it "renders the employment-focused entry content instead of the default content" do
        get :show, params: { token: invitation.auth_token }

        expect(response.body).to include(I18n.t("activities.entries.show.employment_focused.header"))
        expect(response.body).not_to include(I18n.t("activities.entries.show.title", benefit: "Medicaid"))
      end

      it "links to the employment activity selection screen" do
        get :show, params: { token: invitation.auth_token }

        expect(response.body).to include(activities_flow_income_add_your_work_path)
      end
    end

    context "when the flow is not employment_focused" do
      let(:invitation) { create(:activity_flow_invitation, employment_focused: false) }

      it "renders the default entry content" do
        get :show, params: { token: invitation.auth_token }
        expect(response.body).to include(I18n.t("activities.entries.show.title", benefit: "Medicaid"))
        expect(response.body).not_to include(I18n.t("activities.entries.show.employment_focused.header"))
      end
    end

    context "with an existing activity session" do
      let(:flow) { create(:activity_flow, employment_focused: true) }
      let!(:employment_activity) do
        create(:employment_activity, activity_flow: flow, employer_name: "Example Employer")
      end

      before do
        session[:flow_id] = flow.id
        session[:flow_type] = :activity
      end

      it "reuses the flow without creating another flow or applicant" do
        expect {
          get :show
        }.to change(ActivityFlow, :count).by(0)
          .and change(CbvApplicant, :count).by(0)

        expect(session[:flow_id]).to eq(flow.id)
        expect(flow.reload.employment_activities).to include(employment_activity)
      end

      it "renders the employment-focused entry page" do
        get :show

        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_selector(
          "h1",
          text: I18n.t("activities.entries.show.employment_focused.header")
        )
      end

      context "when the session flow type is a string" do
        before { session[:flow_type] = "activity" }

        it "reuses the existing flow" do
          expect {
            get :show
          }.not_to change(ActivityFlow, :count)

          expect(session[:flow_id]).to eq(flow.id)
        end
      end
    end
  end
end
