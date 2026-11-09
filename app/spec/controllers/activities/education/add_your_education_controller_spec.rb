require "rails_helper"

RSpec.describe Activities::Education::AddYourEducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "#show" do
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) { get :show }

    it_behaves_like "tracks an event", TrackEvent::EducationAddYourEducationViewed

    it "tracks the choice page without classifying the education path" do
      expect(EventTrackingJob).to receive(:perform_later).with(
        TrackEvent::EducationAddYourEducationViewed, anything,
        hash_excluding(:education_flow, :education_data_source, :education_type, :education_activity_id, :nsc_status))

      get :show
    end

    it "tracks the choice page even when NSC is disabled" do
      expect(EventTrackingJob).to receive(:perform_later).with(
        TrackEvent::EducationAddYourEducationViewed, anything,
        hash_excluding(:education_flow, :education_data_source))

      stub_environment_variable("NSC_DISABLED", "true") { get :show }
    end

    it "does not track a page view when a completed flow is redirected" do
      activity_flow.update!(completed_at: Time.current)
      expect(EventTrackingJob).not_to receive(:perform_later).with(
        TrackEvent::EducationAddYourEducationViewed, anything, anything)

      get :show

      expect(response).to have_http_status(:redirect)
    end

    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    it "renders the header, reporting period, and description" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.add_your_education.show.header"))
      expect(response.body).to include(I18n.t("activities.education.add_your_education.show.reporting_period_label"))
      expect(response.body).to include(activity_flow.reporting_window_display)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.description")))
    end

    it "renders all four options with bolded labels and hints for relevant options" do
      get :show

      %w[college high_school_ged trade_or_technical].each do |option|
        label = CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.options.#{option}.label"))
        expect(response.body).to include("<span class=\"text-bold\">#{label}</span>")
        expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.options.#{option}.hint")))
      end

      other_label = CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.options.other.label"))
      expect(response.body).to include("<span class=\"text-bold\">#{other_label}</span>")
    end

    it "does not render the hint as an attribute on the radio input" do
      get :show
      expect(response.body).not_to include("hint=")
    end

    it "renders the activity flow header with exit button and no back link" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
      expect(Capybara.string(response.body)).not_to have_link("Back")
    end

    context "after submitting without a selection" do
      before do
        post :create
        get :show
      end

      it "renders the slim error alert between the introduction and the choices" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_selector(
          "h1 ~ p + .usa-alert--error.usa-alert--slim",
          text: I18n.t("shared.next_path.notice_no_answer")
        )
        expect(rendered).to have_selector(".usa-alert + form#add_your_education_form")
      end
    end
  end

  describe "#create" do
    context "tracking a submitted selection" do
      let(:activity_flow) { create(:activity_flow, activity_flow_invitation: create(:activity_flow_invitation)) }

      context "when college or university is selected" do
        it "tracks the selected education type with flow context" do
          expect(EventTrackingJob).to receive(:perform_later).with(
            TrackEvent::EducationAddYourEducationSubmitted, anything,
            hash_including(education_type: "college_or_university", cbv_flow_id: activity_flow.id,
              cbv_applicant_id: activity_flow.cbv_applicant_id, invitation_id: activity_flow.invitation_id,
              client_agency_id: activity_flow.cbv_applicant.client_agency_id))

          post :create, params: { add_education_method: "college_or_university" }
        end

        it "tracks the selection when NSC is disabled" do
          expect(EventTrackingJob).to receive(:perform_later).with(
            TrackEvent::EducationAddYourEducationSubmitted, anything,
            hash_including(education_type: "college_or_university"))

          stub_environment_variable("NSC_DISABLED", "true") do
            post :create, params: { add_education_method: "college_or_university" }
          end
        end
      end

      context "when high school or GED is selected" do
        it "tracks the selected education type" do
          expect(EventTrackingJob).to receive(:perform_later).with(
            TrackEvent::EducationAddYourEducationSubmitted, anything,
            hash_including(education_type: "high_school_ged"))

          post :create, params: { add_education_method: "high_school_ged" }
        end
      end

      context "when trade or technical education is selected" do
        it "tracks the selected education type" do
          expect(EventTrackingJob).to receive(:perform_later).with(
            TrackEvent::EducationAddYourEducationSubmitted, anything,
            hash_including(education_type: "trade_or_technical"))

          post :create, params: { add_education_method: "trade_or_technical" }
        end
      end

      context "when other is selected" do
        it "tracks the selected education type" do
          expect(EventTrackingJob).to receive(:perform_later).with(
            TrackEvent::EducationAddYourEducationSubmitted, anything,
            hash_including(education_type: "other"))

          post :create, params: { add_education_method: "other" }
        end
      end

      context "when nothing is selected" do
        it "does not track a submitted selection" do
          expect(EventTrackingJob).not_to receive(:perform_later)
            .with(TrackEvent::EducationAddYourEducationSubmitted, anything, anything)

          post :create
        end
      end

      context "when an unrecognized option is submitted" do
        it "does not track a submitted selection" do
          expect(EventTrackingJob).not_to receive(:perform_later)
            .with(TrackEvent::EducationAddYourEducationSubmitted, anything, anything)

          post :create, params: { add_education_method: "something_else" }
        end
      end

      context "when the flow is already completed" do
        before { activity_flow.update!(completed_at: Time.current) }

        it "does not track a submitted selection" do
          expect(EventTrackingJob).not_to receive(:perform_later)
            .with(TrackEvent::EducationAddYourEducationSubmitted, anything, anything)

          post :create, params: { add_education_method: "other" }
        end
      end
    end

    it "redirects to verify enrollment when college or university is selected" do
      post :create, params: { add_education_method: "college_or_university" }
      expect(response).to redirect_to(verify_activities_flow_education_index_path(education_type: "college_or_university"))
    end

    it "redirects to self-attested education when college or university is selected and NSC is disabled" do
      stub_environment_variable("NSC_DISABLED", "true") do
        post :create, params: { add_education_method: "college_or_university" }
        expect(response).to redirect_to(new_activities_flow_education_path(education_type: "college_or_university"))
      end
    end

    it "redirects to self-attested education when high school or GED is selected" do
      post :create, params: { add_education_method: "high_school_ged" }
      expect(response).to redirect_to(new_activities_flow_education_path(education_type: "high_school_ged"))
    end

    it "redirects to self-attested education when trade or technical program is selected" do
      post :create, params: { add_education_method: "trade_or_technical" }
      expect(response).to redirect_to(new_activities_flow_education_path(education_type: "trade_or_technical"))
    end

    it "redirects to other education routing page when other is selected" do
      post :create, params: { add_education_method: "other" }
      expect(response).to redirect_to(activities_flow_education_other_path(education_type: "other"))
    end

    it "redirects back with an alert when nothing is selected" do
      post :create
      expect(flash[:education_selection_error]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_education_add_your_education_path)
    end

    it "redirects back with an alert when the selection is not recognized" do
      post :create, params: { add_education_method: "something_else" }
      expect(flash[:education_selection_error]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_education_add_your_education_path)
    end
  end
end
