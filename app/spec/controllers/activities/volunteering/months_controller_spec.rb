require "rails_helper"

RSpec.describe Activities::Volunteering::MonthsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
  let(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    it "redirects to month 0 for an out-of-range month index" do
      get :edit, params: { volunteering_id: volunteering_activity.id, id: 99 }

      expect(response).to redirect_to(edit_activities_flow_volunteering_month_path(volunteering_id: volunteering_activity, id: 0))
    end
  end

  describe "PATCH #update" do
    it "redirects to document upload" do
      patch :update, params: { volunteering_id: volunteering_activity.id, id: 0, volunteering_activity_month: { hours: 1 } }

      expect(response).to redirect_to(new_activities_flow_volunteering_document_upload_path(volunteering_id: volunteering_activity.id))
    end

    context "with multiple reporting months" do
      let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

      it "advances to next month when hours are blank" do
        patch :update, params: { volunteering_id: volunteering_activity.id, id: 0, volunteering_activity_month: { hours: "" } }

        expect(response).to redirect_to(edit_activities_flow_volunteering_month_path(volunteering_id: volunteering_activity, id: 1))
      end
    end
  end

  describe "PATCH #update with from_review" do
    let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

    it "redirects back to review instead of advancing to next month" do
      patch :update, params: { volunteering_id: volunteering_activity.id, id: 0, from_review: 1, volunteering_activity_month: { hours: 15 } }

      expect(response).to redirect_to(review_activities_flow_volunteering_path(id: volunteering_activity))
    end

    it "validates at least one month has hours when editing from review" do
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, month: activity_flow.reporting_months.first, hours: 10)
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, month: activity_flow.reporting_months.second, hours: 0)

      patch :update, params: { volunteering_id: volunteering_activity.id, id: 0, from_review: 1, volunteering_activity_month: { hours: 0 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "allows saving when another month still has hours" do
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, month: activity_flow.reporting_months.first, hours: 10)
      create(:volunteering_activity_month, volunteering_activity: volunteering_activity, month: activity_flow.reporting_months.second, hours: 5)

      patch :update, params: { volunteering_id: volunteering_activity.id, id: 0, from_review: 1, volunteering_activity_month: { hours: 0 } }

      expect(response).to redirect_to(review_activities_flow_volunteering_path(id: volunteering_activity))
    end
  end
end
