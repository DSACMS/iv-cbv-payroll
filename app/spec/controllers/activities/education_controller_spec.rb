require "rails_helper"
require "faker"

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      education_activities_count: 0,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      with_identity: true
    )
  }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #verify" do
    it "renders the user's details" do
      get :verify

      expect(response.body).to have_content(activity_flow.identity.first_name)
      expect(response.body).to have_content(activity_flow.identity.last_name)
      expect(response.body).to have_content(activity_flow.identity.date_of_birth.strftime("%B %-d, %Y"))
    end
  end

  describe "POST #create" do
    it "creates a validated EducationActivity and redirects to #show" do
      expect { post :create }
        .to change(EducationActivity, :count)
        .by(1)

      expect(EducationActivity.last.data_source).to eq("validated")
      expect(response).to redirect_to(activities_flow_education_path(id: EducationActivity.last.id))
    end

    it "creates a self-attested EducationActivity and redirects to month 0" do
      expect {
        post :create, params: { education_activity: { school_name: "Test University", city: "Springfield", state: "IL", zip_code: "62701", street_address: "123 Main St" } }
      }.to change(EducationActivity, :count).by(1)

      activity = EducationActivity.last
      expect(activity.data_source).to eq("fully_self_attested")
      expect(activity.school_name).to eq("Test University")
      expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: activity.id, id: 0))
    end

    it "re-renders the form when self-attested params are invalid" do
      post :create, params: { education_activity: { school_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET #show" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "renders the synchronization page" do
      get :show, params: { id: education_activity.id }

      expect(response).to have_http_status(:ok)
    end

    context "when the EducationActivity has no enrollments" do
      before do
        education_activity.update(status: :no_enrollments)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the error page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(activities_flow_education_error_path)
      end
    end

    context "when the EducationActivity sync failed" do
      before do
        education_activity.update(status: :failed)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the error page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(activities_flow_education_error_path)
      end
    end

    context "when the EducationActivity has succeeded" do
      before do
        education_activity.update(status: :succeeded)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to the edit page" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(edit_activities_flow_education_path(id: education_activity.id))
      end
    end

    context "when the EducationActivity is partially self-attested and succeeded" do
      before do
        education_activity.update(status: :succeeded, data_source: :partially_self_attested)
        create(:nsc_enrollment_term, :less_than_half_time, education_activity: education_activity)
        allow(controller).to receive(:testing_synchronization_page?)
          .and_return(false)
      end

      it "redirects to term credit hours" do
        get :show, params: { id: education_activity.id }

        expect(response).to redirect_to(
          edit_activities_flow_education_term_credit_hour_path(education_id: education_activity.id, id: 0)
        )
      end
    end
  end

  describe "GET #error" do
    it "renders the error page with retry and manual entry options" do
      get :error

      expect(response).to have_http_status(:ok)
      expect(response.body).to have_content(I18n.t("activities.education.error.enter_manually_button"))
      expect(response.body).to have_content(I18n.t("activities.education.error.retry_button"))
      expect(response.body).to have_link(I18n.t("activities.education.error.enter_manually_button"), href: new_activities_flow_education_path)
    end
  end

  describe "GET #new" do
    it "renders the self-attestation education form" do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to have_content(I18n.t("activities.education.new.title"))
    end
  end

  describe "GET #edit" do
    let(:self_attested_activity) do
      create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "Test University")
    end

    it "renders the fully self-attested education info form for fully self-attested activities" do
      get :edit, params: { id: self_attested_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.education.new.edit_title"))
      expect(Capybara.string(response.body)).to have_field("education_activity_school_name", with: "Test University")
    end

    it "raises RecordNotFound when the activity is missing" do
      expect {
        get :edit, params: { id: "99999999" }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "sets back_url to review when from_review is present" do
      get :edit, params: { id: self_attested_activity.id, from_review: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: self_attested_activity)
      )
    end

    it "threads from_edit into the back_url when from_review is present" do
      get :edit, params: { id: self_attested_activity.id, from_review: 1, from_edit: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: self_attested_activity, from_edit: 1)
      )
    end

    it "has no back_url when from_review is absent" do
      get :edit, params: { id: self_attested_activity.id }

      expect(assigns(:back_url)).to be_nil
    end

    it "renders Save button when from_review is present" do
      get :edit, params: { id: self_attested_activity.id, from_review: 1 }

      expect(Capybara.string(response.body)).to have_button(I18n.t("activities.hub.save"))
    end

    it "renders Continue button when from_review is absent" do
      get :edit, params: { id: self_attested_activity.id }

      expect(Capybara.string(response.body)).to have_button(I18n.t("activities.education.new.continue"))
    end
  end

  describe "DELETE #destroy" do
    let!(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { id: education_activity.id }, session: { flow_id: activity_flow.id, flow_type: :activity }
      end.to change(activity_flow.education_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "GET #review" do
    context "when fully self-attested" do
      let(:education_activity) do
        create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "University of Illinois")
      end

      it "renders the review page" do
        get :review, params: { id: education_activity.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(education_activity.school_name)
      end

      it "displays education activity months" do
        create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.first, hours: 4)

        get :review, params: { id: education_activity.id }

        expect(response.body).to include("4")
        expect(response.body).to include("16")
      end

      it "renders an edit link to school info with from_review" do
        get :review, params: { id: education_activity.id }

        doc = Capybara.string(response.body)
        edit_link = doc.find("a", text: I18n.t("activities.hub.edit"))
        expect(edit_link[:href]).to include("from_review=1")
      end
    end

    context "when partially self-attested" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: activity_flow,
          data_source: :partially_self_attested,
          status: :succeeded
        )
      end

      it "renders enrollment review details for a single enrollment and fallback term hours" do
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          school_name: "University of Illinois"
        )

        get :review, params: { id: education_activity.id }

        doc = Capybara.string(response.body)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("activities.education.review.enrollment_information"))
        expect(response.body).to include(I18n.t("components.enrollment_term_table_component.school_or_program"))
        expect(response.body).to include(I18n.t("activities.education.review.credit_hours_section"))
        expect(response.body).to include(I18n.t("activities.education.review.community_engagement_hours"))
        expect(response.body).to include(I18n.t("activities.education.review.ce_explainer_title"))
        expect(doc).to have_text(I18n.t("activities.education.review.description", school_name: "University of Illinois"))
        expect(response.body).to include("0")
      end

      it "renders term-hours table for an enrolled term" do
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          school_name: "University of Illinois",
          enrollment_status: :enrolled,
          credit_hours: 4
        )

        get :review, params: { id: education_activity.id }

        doc = Capybara.string(response.body)
        expect(doc).to have_selector("h3", text: I18n.t("activities.education.review.credit_hours_section"), count: 1)
        expect(response.body).to include(I18n.t("activities.education.review.community_engagement_hours"))
      end

      it "renders term-hours edit link to the term credit-hours screen" do
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          school_name: "University of Illinois"
        )

        get :review, params: { id: education_activity.id }

        expect(response.body).to include(
          edit_activities_flow_education_term_credit_hour_path(
            education_id: education_activity.id,
            id: 0,
            from_review: 1
          )
        )
      end

      it "renders multiple enrollments and only shows term-hours table for less-than-half-time terms" do
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          school_name: "Half Time School",
          enrollment_status: :half_time
        )
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          school_name: "Less Than Half School",
          credit_hours: 4
        )

        get :review, params: { id: education_activity.id }

        doc = Capybara.string(response.body)
        expect(response.body).to include(I18n.t("activities.education.review.enrollment_information_numbered", number: 1))
        expect(response.body).to include(I18n.t("activities.education.review.enrollment_information_numbered", number: 2))
        expect(doc).to have_selector("h1", text: I18n.t("activities.education.review.title_no_school_name"))
        expect(doc).to have_text(
          I18n.t(
            "activities.education.review.description",
            school_name: "Half Time School and Less Than Half School"
          )
        )
        expect(doc).to have_selector("h3", text: I18n.t("activities.education.review.credit_hours_section"), count: 1)
        expect(response.body.scan(I18n.t("activities.education.review.ce_explainer_title")).count).to eq(1)
        expect(response.body.scan(I18n.t("activities.education.review.community_engagement_hours")).count).to eq(1)
      end

      it "renders term-hours tables for each enrollment when all enrollments are less-than-half-time" do
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          school_name: "School One",
          credit_hours: 3
        )
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          school_name: "School Two",
          credit_hours: 5
        )

        get :review, params: { id: education_activity.id }

        doc = Capybara.string(response.body)
        expect(response.body).to include(I18n.t("activities.education.review.enrollment_information_numbered", number: 1))
        expect(response.body).to include(I18n.t("activities.education.review.enrollment_information_numbered", number: 2))
        expect(doc).to have_selector("h1", text: I18n.t("activities.education.review.title_no_school_name"))
        expect(doc).to have_text(
          I18n.t(
            "activities.education.review.description",
            school_name: "School One and School Two"
          )
        )
        expect(doc).to have_selector("h3", text: I18n.t("activities.education.review.credit_hours_section"), count: 2)
        expect(response.body.scan(I18n.t("activities.education.review.community_engagement_hours")).count).to eq(2)
        expect(response.body.scan(I18n.t("activities.education.review.ce_explainer_title")).count).to eq(1)
      end
    end

    it "sets back_url to document uploads when from_edit is absent" do
      education_activity = create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "University of Illinois")

      get :review, params: { id: education_activity.id }

      expect(assigns(:back_url)).to eq(
        new_activities_flow_education_document_upload_path(education_id: education_activity)
      )
    end

    it "has no back_url when from_edit is present" do
      education_activity = create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "University of Illinois")

      get :review, params: { id: education_activity.id, from_edit: 1 }

      expect(assigns(:back_url)).to be_nil
    end
  end

  describe "PATCH #save_review" do
    let(:education_activity) do
      create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "University of Illinois")
    end

    it "saves additional comments and redirects to the hub" do
      patch :save_review, params: { id: education_activity.id, education_activity: { additional_comments: "Some notes" } }

      expect(education_activity.reload.additional_comments).to eq("Some notes")
      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "PATCH #update" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    it "updates the activity" do
      patch :update, params: {
        id: education_activity.id,
        education_activity: {
          credit_hours: 12,
          additional_comments: "this is a test"
        }
      }
      expect(education_activity.reload).to have_attributes(
        credit_hours: 12,
        additional_comments: "this is a test"
      )
      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold is not met" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 40,
        meets_requirements: false,
        meets_routing_requirements: false
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to activity hub when threshold met but only via self-attested data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: false
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to summary when threshold is met via validated data" do
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 80,
        meets_requirements: true,
        meets_routing_requirements: true
      )
      allow(controller).to receive(:progress_calculator).and_return(instance_double(ActivityFlowProgressCalculator, overall_result: result))

      patch :update, params: {
        id: education_activity.id,
        education_activity: { credit_hours: 12 }
      }

      expect(response).to redirect_to(activities_flow_summary_path)
    end

    it "redirects partially self-attested activities to term credit hours" do
      partially_self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
      create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: partially_self_attested_activity,
        school_name: "State University")

      patch :update, params: {
        id: partially_self_attested_activity.id,
        education_activity: { additional_comments: "Needs docs" }
      }

      expect(response).to redirect_to(
        edit_activities_flow_education_term_credit_hour_path(education_id: partially_self_attested_activity.id, id: 0)
      )
    end

    context "when validated activity has less-than-half-time terms" do
      let(:validated_activity) { create(:education_activity, activity_flow: activity_flow, status: :succeeded) }

      before do
        create(:nsc_enrollment_term, :less_than_half_time,
          education_activity: validated_activity,
          school_name: "State University")
      end

      it "redirects to term credit hours instead of after_activity_path" do
        patch :update, params: {
          id: validated_activity.id,
          education_activity: { additional_comments: "test" }
        }

        expect(response).to redirect_to(
          edit_activities_flow_education_term_credit_hour_path(
            education_id: validated_activity, id: 0
          )
        )
      end
    end

    context "when validated activity has only half-time-or-above terms" do
      let(:validated_activity) { create(:education_activity, activity_flow: activity_flow, status: :succeeded) }

      before do
        create(:nsc_enrollment_term,
          education_activity: validated_activity,
          enrollment_status: "half_time",
          school_name: "State University")

        result = ActivityFlowProgressCalculator::OverallResult.new(
          total_hours: 0,
          meets_requirements: false,
          meets_routing_requirements: false
        )
        allow(controller).to receive(:progress_calculator).and_return(
          instance_double(ActivityFlowProgressCalculator, overall_result: result)
        )
      end

      it "redirects to after_activity_path (not term credit hours)" do
        patch :update, params: {
          id: validated_activity.id,
          education_activity: { additional_comments: "test" }
        }

        expect(response).to redirect_to(activities_flow_root_path)
      end
    end

    it "updates fully self-attested education info and redirects to month 0" do
      fully_self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Old School"
      )

      patch :update, params: {
        id: fully_self_attested_activity.id,
        education_activity: {
          school_name: "New School",
          city: "New City",
          state: "CA",
          zip_code: "90001",
          street_address: "123 Main St"
        }
      }

      expect(fully_self_attested_activity.reload.school_name).to eq("New School")
      expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: fully_self_attested_activity, id: 0))
    end

    it "redirects self-attested to review when from_review is present" do
      self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Old School"
      )

      patch :update, params: {
        id: self_attested_activity.id,
        from_review: 1,
        education_activity: {
          school_name: "New School",
          city: "New City",
          state: "CA",
          zip_code: "90001",
          street_address: "123 Main St"
        }
      }

      expect(response).to redirect_to(review_activities_flow_education_path(id: self_attested_activity))
    end

    it "threads from_edit to review when from_review is present" do
      self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Old School"
      )

      patch :update, params: {
        id: self_attested_activity.id,
        from_review: 1,
        from_edit: 1,
        education_activity: {
          school_name: "New School",
          city: "New City",
          state: "CA",
          zip_code: "90001",
          street_address: "123 Main St"
        }
      }

      expect(response).to redirect_to(review_activities_flow_education_path(id: self_attested_activity, from_edit: 1))
    end

    it "threads from_edit to month 0 when from_review is absent" do
      self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Old School"
      )

      patch :update, params: {
        id: self_attested_activity.id,
        from_edit: 1,
        education_activity: {
          school_name: "New School",
          city: "New City",
          state: "CA",
          zip_code: "90001",
          street_address: "123 Main St"
        }
      }

      expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: self_attested_activity, id: 0, from_edit: 1))
    end
  end
end
