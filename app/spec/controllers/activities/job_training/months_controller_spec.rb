require "rails_helper"

RSpec.describe Activities::JobTraining::MonthsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
  let(:job_training_activity) { create(:job_training_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    it "redirects to month 0 for an out-of-range month index" do
      get :edit, params: { job_training_id: job_training_activity.id, id: 99 }

      expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: job_training_activity, id: 0))
    end
  end

  describe "PATCH #update" do
    it "redirects to document upload on a single-month flow when hours are positive" do
      patch :update, params: { job_training_id: job_training_activity.id, id: 0, job_training_activity_month: { hours: 1 } }

      expect(response).to redirect_to(new_activities_flow_job_training_document_upload_path(job_training_id: job_training_activity.id))
    end

    it "returns an error on a single-month flow when no-hours checkbox is selected" do
      patch :update, params: { job_training_id: job_training_activity.id, id: 0, no_hours: "1" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(assigns(:back_url)).to be_present
      expect(response.body).to include("back-nav")
    end

    context "with multiple reporting months" do
      let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

      it "advances to the next month when hours are blank" do
        patch :update, params: { job_training_id: job_training_activity.id, id: 0, job_training_activity_month: { hours: "" } }

        expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: job_training_activity, id: 1))
      end

      it "stores 0 hours when no-hours checkbox is selected and advances" do
        patch :update, params: { job_training_id: job_training_activity.id, id: 0, no_hours: "1" }

        first_month = activity_flow.reporting_months.first.beginning_of_month
        expect(job_training_activity.job_training_activity_months.find_by(month: first_month)&.hours).to eq(0)
        expect(response).to redirect_to(edit_activities_flow_job_training_month_path(job_training_id: job_training_activity, id: 1))
      end

      it "requires at least one month with hours > 0 by the final month" do
        create(:job_training_activity_month, job_training_activity: job_training_activity, month: activity_flow.reporting_months.first, hours: 0)
        create(:job_training_activity_month, job_training_activity: job_training_activity, month: activity_flow.reporting_months.second, hours: 0)

        patch :update, params: { job_training_id: job_training_activity.id, id: 2, no_hours: "1" }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "allows final month save when another month has hours" do
        create(:job_training_activity_month, job_training_activity: job_training_activity, month: activity_flow.reporting_months.first, hours: 12)
        create(:job_training_activity_month, job_training_activity: job_training_activity, month: activity_flow.reporting_months.second, hours: 0)

        patch :update, params: { job_training_id: job_training_activity.id, id: 2, no_hours: "1" }

        expect(response).to redirect_to(new_activities_flow_job_training_document_upload_path(job_training_id: job_training_activity.id))
      end
    end

    context "when editing from review" do
      let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

      it "redirects back to the review page" do
        create(:job_training_activity_month, job_training_activity: job_training_activity, month: activity_flow.reporting_months.second, hours: 10)

        patch :update, params: { job_training_id: job_training_activity.id, id: 0, from_review: 1, job_training_activity_month: { hours: 15 } }

        expect(response).to redirect_to(review_activities_flow_job_training_path(id: job_training_activity))
      end
    end
  end
end
