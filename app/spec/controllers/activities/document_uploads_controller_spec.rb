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

    it "redirects to hub for job training" do
      job_training_activity = create(:job_training_activity, activity_flow: activity_flow)

      post :create, params: { job_training_id: job_training_activity.id }

      expect(response).to redirect_to(activities_flow_root_path)
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
end
