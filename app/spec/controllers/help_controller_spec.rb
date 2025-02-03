require 'rails_helper'

RSpec.describe HelpController, type: :controller do
  describe "GET #show" do
    let(:valid_params) do
      {
        topic: "employer",
        site_id: "sandbox"
      }
    end

    context "with a valid CBV flow" do
      let(:cbv_flow) { create(:cbv_flow) }

      before do
        session[:cbv_flow_id] = cbv_flow.id
        valid_params[:site_id] = cbv_flow.site_id
      end

      it "tracks events with both trackers" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantViewedHelpTopic", be_an(ActionController::TestRequest), hash_including(
            browser: nil,
            cbv_flow_id: cbv_flow.id,
            device_name: nil,
            device_type: nil,
            ip: "0.0.0.0",
            language: I18n.locale,
            locale: nil,
            site_id: cbv_flow.site_id,
            topic: "employer",
            user_agent: "Rails Testing"
          ))

        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantViewedHelpTopic", be_an(ActionController::TestRequest), hash_including(
            browser: nil,
            cbv_flow_id: cbv_flow.id,
            device_name: nil,
            device_type: nil,
            ip: "0.0.0.0",
            language: I18n.locale,
            locale: nil,
            site_id: cbv_flow.site_id,
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
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantViewedHelpTopic", be_an(ActionController::TestRequest), hash_including(
            browser: nil,
            cbv_flow_id: nil,
            device_name: nil,
            device_type: nil,
            ip: "0.0.0.0",
            language: I18n.locale,
            locale: nil,
            site_id: "sandbox",
            topic: "employer",
            user_agent: "Rails Testing"
          ))

        get :show, params: valid_params
        expect(response).to render_template(:show)
        expect(assigns(:help_topic)).to eq("employer")
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
