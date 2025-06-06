require 'rails_helper'

RSpec.describe HelpController, type: :controller do
  describe "GET #show" do
    let(:valid_params) do
      {
        topic: "employer",
        client_agency_id: "sandbox"
      }
    end

    context "with a valid CBV flow" do
      let(:cbv_flow) { create(:cbv_flow, :invited) }

      before do
        session[:cbv_flow_id] = cbv_flow.id
        valid_params[:client_agency_id] = cbv_flow.client_agency_id
      end

      it "tracks events for help topic" do
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantViewedHelpTopic", anything, hash_including(
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            ip: "0.0.0.0",
            locale: I18n.locale,
            client_agency_id: cbv_flow.client_agency_id,
            topic: "employer",
            user_agent: "Rails Testing"
          ))

        get :show, params: valid_params
      end

      it "assigns instance variables and renders template" do
        get :show, params: valid_params
        expect(response).to render_template(:show)
        expect(assigns(:help_topic)).to eq("employer")
        expect(assigns(:title)).to eq(I18n.t("help.show.employer.title"))
      end
    end

    context "without a CBV flow" do
      it "still renders the template and tracks events" do
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantViewedHelpTopic", anything, hash_including(
            ip: "0.0.0.0",
            locale: I18n.locale,
            client_agency_id: "sandbox",
            topic: "employer",
            user_agent: "Rails Testing"
          ))

        get :show, params: valid_params
        expect(response).to render_template(:show)
        expect(assigns(:help_topic)).to eq("employer")
        expect(assigns(:title)).to eq(I18n.t("help.show.employer.title"))
      end
    end

    context "with a hyphenated topic" do
      it "converts hyphens to underscores" do
        get :show, params: valid_params.merge(topic: "company-id")
        expect(assigns(:help_topic)).to eq("company_id")
        expect(assigns(:title)).to eq(I18n.t("help.show.company_id.title"))
      end
    end
  end

  describe "GET #index" do
    it "assigns title and renders template" do
      get :index, params: { site_id: "sandbox" }
      expect(assigns(:title)).to eq(I18n.t("help.index.title"))
      expect(response).to render_template(:index)
    end
  end
end
