require "rails_helper"

RSpec.describe Activities::Employment::MonthsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: reporting_window_months
    )
  end
  let(:reporting_window_months) { 1 }
  let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    it "redirects to month 0 for an out-of-range month index" do
      get :edit, params: { employment_id: employment_activity.id, id: 99 }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0)
      )
    end

    it "renders the gross income currency field" do
      get :edit, params: { employment_id: employment_activity.id, id: 0 }

      expect(response.body).to include("usa-input-prefix")
    end
  end

  describe "PATCH #update" do
    it "saves month values and redirects to document upload on single month flows" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }

      expect(response).to redirect_to(new_activities_flow_income_employment_document_upload_path(employment_id: employment_activity))
      month = employment_activity.activity_months.last
      expect(month.gross_income).to eq(339)
      expect(month.hours).to eq(45)
    end

    it "threads from_edit to document upload redirect" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        from_edit: 1,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }

      expect(response).to redirect_to(
        new_activities_flow_income_employment_document_upload_path(
          employment_id: employment_activity,
          from_edit: 1
        )
      )
    end

    context "with multiple reporting months" do
      let(:reporting_window_months) { 3 }

      it "sets gross income and hours to zero when no income is checked" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          no_hours: "1",
          employment_activity_month: { gross_income: 339, hours: 45 }
        }

        month = employment_activity.activity_months.last
        expect(month.gross_income).to eq(0)
        expect(month.hours).to eq(0)
      end

      it "advances to next month when month 1 is blank" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: "", hours: "" }
        }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 1)
        )
      end

      it "requires at least one month with both income and hours on the last page" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 2,
          employment_activity_month: { gross_income: 0, hours: 0 }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
