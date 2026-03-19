require "rails_helper"

RSpec.describe Activities::Education::TermCreditHoursController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 1
    )
  }
  let(:education_activity) {
    create(:education_activity, activity_flow: activity_flow, status: :succeeded)
  }
  let(:less_than_half_time_term) {
    create(:nsc_enrollment_term, :less_than_half_time,
      education_activity: education_activity,
      school_name: "State University")
  }

  before do
    less_than_half_time_term
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    it "renders the term credit hours input screen" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response).to have_http_status(:ok)
    end

    it "shows the school name from the NSC term" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response.body).to include("State University")
    end

    it "shows the term date range" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response.body).to include("Term:")
    end

    it "shows body copy with the term begin and end dates" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expected_body = I18n.t(
        "activities.education.term_credit_hours.body_html",
        term_begin: I18n.l(less_than_half_time_term.term_begin.to_date, format: :long),
        term_end: I18n.l(less_than_half_time_term.term_end.to_date, format: :long)
      )

      expect(response.body).to include(expected_body)
      expect(response.body).to include(I18n.t("activities.education.term_credit_hours.body_conversion"))
    end

    it "does not show checkbox for a single term" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response.body).not_to include("no_hours")
    end

    it "redirects to index 0 for an out-of-range index" do
      get :edit, params: { education_id: education_activity.id, id: 99 }

      expect(response).to redirect_to(
        edit_activities_flow_education_term_credit_hour_path(
          education_id: education_activity, id: 0
        )
      )
    end

    it "redirects to after_activity_path when no less-than-half-time terms exist" do
      less_than_half_time_term.update!(enrollment_status: "half_time")
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 0,
        meets_requirements: false,
        meets_routing_requirements: false
      )
      allow(controller).to receive(:progress_calculator).and_return(
        instance_double(ActivityFlowProgressCalculator, overall_result: result)
      )

      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "GET #edit with multiple terms" do
    let(:activity_flow) {
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0,
        reporting_window_months: 6
      )
    }

    before do
      range = activity_flow.reporting_window_range
      create(:nsc_enrollment_term, :less_than_half_time,
        education_activity: education_activity,
        school_name: "State University",
        term_begin: range.begin + 3.months,
        term_end: range.end)
    end

    it "shows checkbox for multi-term" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response.body).to include("no_hours")
    end
  end

  describe "GET #edit back_url" do
    render_views false

    it "sets back_url to education edit for term 0" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(assigns(:back_url)).to eq(
        edit_activities_flow_education_path(id: education_activity)
      )
    end

    context "with multiple terms" do
      let(:activity_flow) {
        create(
          :activity_flow,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0,
          reporting_window_months: 6
        )
      }

      before do
        range = activity_flow.reporting_window_range
        create(:nsc_enrollment_term, :less_than_half_time,
          education_activity: education_activity,
          school_name: "State University",
          term_begin: range.begin + 3.months,
          term_end: range.end)
      end

      it "sets back_url to previous term for term index > 0" do
        get :edit, params: { education_id: education_activity.id, id: 1 }

        expect(assigns(:back_url)).to eq(
          edit_activities_flow_education_term_credit_hour_path(
            education_id: education_activity, id: 0
          )
        )
      end
    end
  end

  describe "PATCH #update" do
    it "saves credit_hours on the NscEnrollmentTerm" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        nsc_enrollment_term: { credit_hours: 4 }
      }

      expect(less_than_half_time_term.reload.credit_hours).to eq(4)
    end

    it "saves 0 when no_hours checkbox is selected" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        no_hours: "1",
        nsc_enrollment_term: { credit_hours: "" }
      }

      expect(less_than_half_time_term.reload.credit_hours).to eq(0)
    end

    it "redirects to document upload on the final term" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        nsc_enrollment_term: { credit_hours: 4 }
      }

      expect(response).to redirect_to(
        new_activities_flow_education_document_upload_path(education_id: education_activity)
      )
    end

    context "with multiple terms" do
      let(:activity_flow) {
        create(
          :activity_flow,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0,
          reporting_window_months: 6
        )
      }

      before do
        range = activity_flow.reporting_window_range
        create(:nsc_enrollment_term, :less_than_half_time,
          education_activity: education_activity,
          school_name: "State University",
          term_begin: range.begin + 3.months,
          term_end: range.end)
      end

      it "redirects to the next term when not the last term" do
        patch :update, params: {
          education_id: education_activity.id,
          id: 0,
          nsc_enrollment_term: { credit_hours: 4 }
        }

        expect(response).to redirect_to(
          edit_activities_flow_education_term_credit_hour_path(
            education_id: education_activity, id: 1
          )
        )
      end

      it "redirects to document upload on the final term" do
        patch :update, params: {
          education_id: education_activity.id,
          id: 1,
          nsc_enrollment_term: { credit_hours: 2 }
        }

        expect(response).to redirect_to(
          new_activities_flow_education_document_upload_path(education_id: education_activity)
        )
      end
    end
  end

  private
end
