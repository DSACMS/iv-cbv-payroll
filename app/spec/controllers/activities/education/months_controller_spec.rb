require "rails_helper"

RSpec.describe Activities::Education::MonthsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow, data_source: :self_attested, school_name: "Test University", status: :succeeded) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    it "redirects to month 0 for an out-of-range month index" do
      get :edit, params: { education_id: education_activity.id, id: 99 }

      expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: education_activity, id: 0))
    end

    it "redirects validated activities away from month screens" do
      education_activity.update!(data_source: :validated)
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "GET #edit back_url" do
    render_views false

    it "sets back_url to school info edit for month 0" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(assigns(:back_url)).to eq(
        edit_activities_flow_education_path(id: education_activity)
      )
    end

    it "sets back_url to review when from_review is present" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: education_activity)
      )
    end

    it "threads from_edit into the back_url when from_review is present" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: education_activity, from_edit: 1)
      )
    end
  end

  describe "GET #edit back_url with multiple reporting months" do
    render_views false

    let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

    it "sets back_url to the previous month for month > 0" do
      get :edit, params: { education_id: education_activity.id, id: 1 }

      expect(assigns(:back_url)).to eq(
        edit_activities_flow_education_month_path(education_id: education_activity, id: 0)
      )
    end

    it "threads from_edit into the previous month back_url" do
      get :edit, params: { education_id: education_activity.id, id: 1, from_edit: 1 }

      expect(assigns(:back_url)).to eq(
        edit_activities_flow_education_month_path(education_id: education_activity, id: 0, from_edit: 1)
      )
    end
  end

  describe "PATCH #update" do
    it "redirects validated activities away from month screens" do
      education_activity.update!(data_source: :validated)
      patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: 5 } }

      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to document uploads when hours are valid" do
      patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: 12 } }

      expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity.id))
    end

    it "redirects back to review when from_review is set" do
      patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: 12 }, from_review: 1 }

      expect(response).to redirect_to(review_activities_flow_education_path(id: education_activity.id))
    end

    it "threads from_edit to review when from_review is set" do
      patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: 12 }, from_review: 1, from_edit: 1 }

      expect(response).to redirect_to(review_activities_flow_education_path(id: education_activity.id, from_edit: 1))
    end

    it "threads from_edit to document uploads on completion" do
      patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: 12 }, from_edit: 1 }

      expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity.id, from_edit: 1))
    end

    it "returns an error on a single-month flow when no-hours checkbox is selected" do
      patch :update, params: { education_id: education_activity.id, id: 0, no_hours: "1" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(assigns(:back_url)).to be_present
      expect(response.body).to include("back-nav")
    end

    context "with multiple reporting months" do
      let(:activity_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 3) }

      it "advances to the next month when hours are blank" do
        patch :update, params: { education_id: education_activity.id, id: 0, education_activity_month: { hours: "" } }

        expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: education_activity, id: 1))
      end

      it "stores 0 hours when no-hours checkbox is selected and advances to next month" do
        patch :update, params: { education_id: education_activity.id, id: 0, no_hours: "1" }

        first_month = activity_flow.reporting_months.first.beginning_of_month
        expect(education_activity.education_activity_months.find_by(month: first_month)&.hours).to eq(0)
        expect(response).to redirect_to(edit_activities_flow_education_month_path(education_id: education_activity, id: 1))
      end

      it "requires at least one month with hours > 0 by the final month" do
        create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.first, hours: 0)
        create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.second, hours: 0)

        patch :update, params: { education_id: education_activity.id, id: 2, no_hours: "1" }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "allows final month save when another month has hours" do
        create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.first, hours: 9)
        create(:education_activity_month, education_activity: education_activity, month: activity_flow.reporting_months.second, hours: 0)

        patch :update, params: { education_id: education_activity.id, id: 2, no_hours: "1" }

        expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity.id))
      end
    end
  end
end
