require "rails_helper"

RSpec.describe Activities::DocumentUploadsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 1
    )
  end

  before do
    Rails.application.config.active_storage.service = :local
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #new" do
    let(:partial_education_activity) do
      create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
    end

    it "renders the upload form for a volunteering activity" do
      volunteering_activity = create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Local Food Bank",
      )
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, hours: 6)

      get :new, params: { community_service_id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: "Local Food Bank"))
      expect(response.body).to include(I18n.t("shared.hours", count: 6))
      expect(response.body).to include(activities_flow_community_service_document_uploads_path)
    end

    it "renders the upload form for a job training activity" do
      job_training_activity = create(
        :job_training_activity,
        activity_flow: activity_flow,
        program_name: "Resume Workshop",
        hours: 10
      )

      get :new, params: { job_training_id: job_training_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: "Resume Workshop"))
      expect(response.body).to include(I18n.t("shared.hours", count: 10))
      expect(response.body).to include(activities_flow_job_training_document_uploads_path)
    end

    it "renders the upload form for an education activity" do
      education_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "University of Illinois"
      )
      create(:education_activity_month, education_activity: education_activity, hours: 15)

      get :new, params: { education_id: education_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: "University of Illinois"))
      expect(response.body).to include(I18n.t("shared.credit_hours", count: 15))
      expect(response.body).to include(activities_flow_education_document_uploads_path)
      expect(response.body).to include(I18n.t("activities.education.document_upload_suggestion_text_html"))
    end

    it "renders the upload form for an employment activity" do
      employment_activity = create(:employment_activity, activity_flow: activity_flow)
      month_record = create(:employment_activity_month, employment_activity: employment_activity, hours: 18)

      get :new, params: { employment_id: employment_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: employment_activity.employer_name))
      expect(response.body).to include(I18n.t("shared.hours", count: month_record.hours))
      expect(response.body).to include(activities_flow_income_employment_document_uploads_path)
      expect(response.body).to include(I18n.t("activities.employment.document_upload_suggestion_text_html"))
    end

    it "renders the upload form for a partially self-attested education activity" do
      term = create_partial_term(
        activity: partial_education_activity,
        school_name: "University of Illinois",
        term_begin: Date.new(2026, 1, 5),
        term_end: Date.new(2026, 5, 15)
      )

      get :new, params: { education_id: partial_education_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: term.school_name))
      expect(response.body).to include("#{I18n.l(term.term_begin, format: :short)} to #{I18n.l(term.term_end, format: :short)}")
    end

    it "uses the simplified title when partially self-attested education has multiple schools" do
      create_partial_term(
        activity: partial_education_activity,
        school_name: "University A",
        term_begin: Date.new(2026, 1, 5),
        term_end: Date.new(2026, 5, 15)
      )
      create_partial_term(
        activity: partial_education_activity,
        school_name: "College B",
        term_begin: Date.new(2026, 1, 10),
        term_end: Date.new(2026, 5, 20)
      )

      get :new, params: { education_id: partial_education_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title_generic"))
      expect(response.body).not_to include(I18n.t("activities.document_uploads.new.title", name: "University A"))
    end

    it "falls back to the file icon when an existing upload preview cannot be processed" do
      volunteering_activity = create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Local Food Bank",
      )
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, hours: 6)
      volunteering_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      allow_any_instance_of(ActiveStorage::Attachment).to receive(:preview).and_raise(StandardError, "preview failed")

      get :new, params: { community_service_id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("verification.pdf")
      expect(response.body).to include("file_present")
    end
  end

  describe "POST #create" do
    it "redirects to review for volunteering when no upload params are provided" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)

      post :create, params: { community_service_id: volunteering_activity.id }

      expect(response).to redirect_to(review_activities_flow_community_service_path(id: volunteering_activity))
    end

    it "attaches uploaded documents to the activity" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)
      upload = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4"),
        "application/pdf",
        original_filename: "verification.pdf"
      )

      expect do
        post :create, params: {
          community_service_id: volunteering_activity.id,
          activity: { document_uploads: [ upload ] }
        }
      end.to change { volunteering_activity.reload.document_uploads.count }.by(1)

      expect(response).to redirect_to(review_activities_flow_community_service_path(id: volunteering_activity))
    end

    it "redirects to review for education when no upload params are provided" do
      education_activity = create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "University of Illinois")

      post :create, params: { education_id: education_activity.id }

      expect(response).to redirect_to(review_activities_flow_education_path(id: education_activity))
    end

    it "redirects to review for job training when no upload params are provided" do
      job_training_activity = create(:job_training_activity, activity_flow: activity_flow)

      post :create, params: { job_training_id: job_training_activity.id }

      expect(response).to redirect_to(review_activities_flow_job_training_path(id: job_training_activity))
    end

    it "redirects to review for employment when no upload params are provided" do
      employment_activity = create(:employment_activity, activity_flow: activity_flow)

      post :create, params: { employment_id: employment_activity.id }

      expect(response).to redirect_to(review_activities_flow_income_employment_path(id: employment_activity))
    end

    it "renders new when the update fails" do
      job_training_activity = create(:job_training_activity, activity_flow: activity_flow)
      allow_any_instance_of(JobTrainingActivity).to receive(:update).and_return(false)

      post :create, params: {
        job_training_id: job_training_activity.id,
        activity: { document_uploads: [ "existing-upload-token" ] }
      }

      expect(response).to render_template(:new)
      expect(response).to have_http_status(:ok)
    end
  end

  def create_partial_term(activity:, school_name:, term_begin:, term_end:)
    create(
      :nsc_enrollment_term,
      :less_than_half_time,
      education_activity: activity,
      school_name: school_name,
      term_begin: term_begin,
      term_end: term_end
    )
  end
end
