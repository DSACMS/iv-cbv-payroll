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
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("")
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("")
    allow_any_instance_of(ActionView::Base).to receive(:image_tag).and_return("")
    allow_any_instance_of(ActionView::Base).to receive(:asset_path).and_wrap_original do |original, source, *args|
      if source.to_s.start_with?("@uswds/uswds/dist/img/sprite.svg")
        "/assets/sprite.svg"
      else
        original.call(source, *args)
      end
    end
    allow_any_instance_of(ActivityFlowHeaderComponent).to receive(:asset_path).and_return("/assets/sprite.svg")
    allow_any_instance_of(DocumentUploadsComponent).to receive(:asset_path).and_return("/assets/sprite.svg")
    allow_any_instance_of(LinkWithIconComponent).to receive(:asset_path).and_return("/assets/sprite.svg")
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
      expect(response.body).not_to include(I18n.t("activities.document_uploads.heading_previous", document_count: 0))
      expect(response.body).to include(I18n.t("activities.document_uploads.new.input_label"))

      rendered = Capybara.string(response.body)
      upload_form = rendered.find("form[data-controller='document-upload']", visible: :all)
      ordered_elements = upload_form.all(
        "[data-document-upload-target='listSection'], input[type='file']",
        visible: :all
      )
      expect(ordered_elements.map { |element| element[:"data-document-upload-target"] })
        .to eq([ "listSection", "input" ])
    end

    it "shows the Save changes label and preserves from_review in the form action when from_review is set" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, hours: 6)

      get :new, params: { community_service_id: volunteering_activity.id, from_review: 1 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.hub.save"))
      expect(response.body).to include(activities_flow_community_service_document_uploads_path(from_review: 1))
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

    context "employment scope" do
      let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }
      let(:tracked_flow) { activity_flow }
      let(:perform_tracked_action) { get :new, params: { employment_id: employment_activity.id } }

      it_behaves_like "tracks an event", TrackEvent::EmploymentDocumentUploadViewed,
        extra_attributes: -> { { employment_activity_id: kind_of(Integer) } }
    end

    context "education scope" do
      let(:education_activity) do
        create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "Test University")
      end
      let(:tracked_flow) { activity_flow }
      let(:perform_tracked_action) { get :new, params: { education_id: education_activity.id } }

      it_behaves_like "tracks an event", TrackEvent::EducationDocumentUploadViewed,
        extra_attributes: -> { { education_activity_id: kind_of(Integer) } }
    end

    it "renders the upload form for an employment activity" do
      employment_activity = create(:employment_activity, activity_flow: activity_flow)
      month_record = create(:employment_activity_month, employment_activity: employment_activity, hours: 18)

      get :new, params: { employment_id: employment_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.new.title", name: employment_activity.employer_name))
      expect(response.body).to include(
        I18n.t(
          "activities.employment.document_upload_month_detail",
          gross_income: ActiveSupport::NumberHelper.number_to_currency(month_record.gross_income),
          hours: I18n.t("shared.hours", count: 18)
        )
      )
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

    it "renders previously uploaded documents in the uploaded documents area" do
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

      get :new, params: { community_service_id: volunteering_activity.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.document_uploads.heading_previous", document_count: 1))
      expect(response.body).to include("verification.pdf")
      expect(response.body).to include(I18n.t("activities.document_uploads.remove_file"))
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

    context "employment scope tracking" do
      let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }
      let(:tracked_flow) { activity_flow }
      let(:perform_tracked_action) { post :create, params: { employment_id: employment_activity.id } }

      it_behaves_like "tracks an event", TrackEvent::EmploymentDocumentUploadSubmitted,
        extra_attributes: -> { { employment_activity_id: kind_of(Integer), document_count: 0 } }
    end

    context "education scope tracking" do
      let(:education_activity) do
        create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested, school_name: "Test University")
      end
      let(:tracked_flow) { activity_flow }
      let(:perform_tracked_action) { post :create, params: { education_id: education_activity.id } }

      it_behaves_like "tracks an event", TrackEvent::EducationDocumentUploadSubmitted,
        extra_attributes: -> { { education_activity_id: kind_of(Integer), document_count: 0 } }
    end

    it "does not track EducationDocumentUploadSubmitted when the update fails" do
      education_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Test University"
      )
      allow_any_instance_of(EducationActivity).to receive(:update).and_return(false)

      expect(EventTrackingJob).not_to receive(:perform_later).with(
        TrackEvent::EducationDocumentUploadSubmitted, anything, anything
      )

      post :create, params: {
        education_id: education_activity.id,
        activity: { document_uploads: [ "existing-upload-token" ] }
      }
    end

    it "does not track EmploymentDocumentUploadSubmitted when the update fails" do
      employment_activity = create(:employment_activity, activity_flow: activity_flow)
      allow_any_instance_of(EmploymentActivity).to receive(:update).and_return(false)

      expect(EventTrackingJob).not_to receive(:perform_later).with(
        TrackEvent::EmploymentDocumentUploadSubmitted, anything, anything
      )

      post :create, params: {
        employment_id: employment_activity.id,
        activity: { document_uploads: [ "existing-upload-token" ] }
      }
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

    context "with a file uploaded directly to the quarantine bucket" do
      let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

      let(:checksum) { Digest::SHA256.base64digest("%PDF-1.4") }

      let(:signed_id) do
        PresignedUploadService.new.call([
          { filename: "verification.pdf", content_type: "application/pdf", byte_size: 8, checksum: checksum }
        ]).first[:signed_id]
      end

      it "attaches the blob the policy endpoint already created" do
        expect do
          post :create, params: {
            community_service_id: volunteering_activity.id,
            activity: { document_uploads: [ signed_id ] }
          }
        end.to change { volunteering_activity.reload.document_uploads.count }.by(1)

        blob = volunteering_activity.document_uploads.last.blob

        expect(blob).to eq(ActiveStorage::Blob.find_signed!(signed_id))
        expect(blob.service_name).to eq(PresignedUploadService::SERVICE_NAME.to_s)
        expect(blob.filename.to_s).to eq("verification.pdf")
      end

      it "keeps previously attached files alongside the new upload" do
        volunteering_activity.document_uploads.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "existing.pdf",
          content_type: "application/pdf"
        )
        existing = volunteering_activity.document_uploads.first

        post :create, params: {
          community_service_id: volunteering_activity.id,
          activity: { document_uploads: [ existing.signed_id, signed_id ] }
        }

        expect(volunteering_activity.reload.document_uploads.map { |u| u.filename.to_s })
          .to contain_exactly("existing.pdf", "verification.pdf")
      end
    end
  end

  describe "DELETE #destroy" do
    it "removes an uploaded volunteering document and redirects back to the upload page" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)
      volunteering_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment_id = volunteering_activity.document_uploads_attachments.first.id

      expect do
        delete :destroy, params: { community_service_id: volunteering_activity.id, id: attachment_id }
      end.to change { volunteering_activity.reload.document_uploads.count }.by(-1)

      expect(response).to redirect_to(
        new_activities_flow_community_service_document_upload_path(community_service_id: volunteering_activity)
      )
    end

    it "removes an uploaded job training document and redirects back to the upload page" do
      job_training_activity = create(:job_training_activity, activity_flow: activity_flow)
      job_training_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment_id = job_training_activity.document_uploads_attachments.first.id

      expect do
        delete :destroy, params: { job_training_id: job_training_activity.id, id: attachment_id }
      end.to change { job_training_activity.reload.document_uploads.count }.by(-1)

      expect(response).to redirect_to(
        new_activities_flow_job_training_document_upload_path(job_training_id: job_training_activity)
      )
    end

    it "removes an uploaded education document and redirects back to the upload page" do
      education_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "University of Illinois"
      )
      education_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment_id = education_activity.document_uploads_attachments.first.id

      expect do
        delete :destroy, params: { education_id: education_activity.id, id: attachment_id }
      end.to change { education_activity.reload.document_uploads.count }.by(-1)

      expect(response).to redirect_to(
        new_activities_flow_education_document_upload_path(education_id: education_activity)
      )
    end

    it "removes an uploaded employment document and redirects back to the upload page" do
      employment_activity = create(:employment_activity, activity_flow: activity_flow)
      employment_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment_id = employment_activity.document_uploads_attachments.first.id

      expect do
        delete :destroy, params: { employment_id: employment_activity.id, id: attachment_id }
      end.to change { employment_activity.reload.document_uploads.count }.by(-1)

      expect(response).to redirect_to(
        new_activities_flow_income_employment_document_upload_path(employment_id: employment_activity)
      )
    end

    it "preserves from_review in the redirect when removing during edit-from-review" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)
      volunteering_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment_id = volunteering_activity.document_uploads_attachments.first.id

      delete :destroy, params: { community_service_id: volunteering_activity.id, id: attachment_id, from_review: 1 }

      expect(response).to redirect_to(
        new_activities_flow_community_service_document_upload_path(community_service_id: volunteering_activity, from_review: 1)
      )
    end

    it "keeps the blob when another activity still has it attached" do
      shared_blob = ActiveStorage::Blob.create!(
        filename: "shared.pdf",
        content_type: "application/pdf",
        byte_size: 8,
        checksum: Digest::SHA256.base64digest("%PDF-1.4"),
        service_name: PresignedUploadService::SERVICE_NAME,
        metadata: { identified: true, analyzed: true }
      )
      first = create(:volunteering_activity, activity_flow: activity_flow)
      second = create(:volunteering_activity, activity_flow: activity_flow)
      first.document_uploads.attach(shared_blob)
      second.document_uploads.attach(shared_blob)

      expect {
        delete :destroy, params: {
          community_service_id: first.id,
          id: first.document_uploads_attachments.first.id
        }
      }.not_to raise_error

      expect(ActiveStorage::Blob.exists?(shared_blob.id)).to be(true)
      expect(second.reload.document_uploads.count).to eq(1)
      expect(first.reload.document_uploads).to be_empty
    end

    it "does not try to delete the object from the quarantine bucket" do
      volunteering_activity = create(:volunteering_activity, activity_flow: activity_flow)
      volunteering_activity.document_uploads.attach(
        io: StringIO.new("%PDF-1.4"),
        filename: "verification.pdf",
        content_type: "application/pdf"
      )
      attachment = volunteering_activity.document_uploads_attachments.first
      blob = attachment.blob

      expect(ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME)).not_to receive(:delete)

      expect do
        delete :destroy, params: { community_service_id: volunteering_activity.id, id: attachment.id }
      end.not_to have_enqueued_job(ActiveStorage::PurgeJob)

      expect(ActiveStorage::Blob.where(id: blob.id)).to be_empty
      expect(volunteering_activity.reload.document_uploads).to be_empty
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
