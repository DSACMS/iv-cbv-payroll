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
    create(:education_activity, activity_flow: activity_flow, data_source: :partially_self_attested, status: :succeeded)
  }
  let(:enrollment_status) { "less_than_half_time" }
  let(:enrollment_term) {
    create(:nsc_enrollment_term, enrollment_status: enrollment_status,
      education_activity: education_activity,
      school_name: "State University")
  }
  let(:page_content) { Capybara.string(response.body) }

  before do
    enrollment_term
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) { get :edit, params: { education_id: education_activity.id, id: 0 } }

    context "when NSC is disabled" do
      it "redirects to the self-attestation new path" do
        stub_environment_variable("NSC_DISABLED", "true") do
          get :edit, params: { education_id: education_activity.id, id: 0 }

          expect(response).to redirect_to(new_activities_flow_education_path)
        end
      end
    end

    it_behaves_like "tracks an event", TrackEvent::EducationTermCreditHoursViewed,
      extra_attributes: -> { { education_activity_id: kind_of(Integer), term_index: 0, term_date_range: kind_of(String) } }

    it "renders the term credit hours input screen" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response).to have_http_status(:ok)
    end

    it "shows the school name from the NSC term" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(page_content).to have_selector("h1", text: I18n.t("activities.education.term_credit_hours.heading", school_name: enrollment_term.school_name))
    end

    it "shows the term date range" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(page_content).to have_text(I18n.t("activities.education.term_credit_hours.term_date_range", range: enrollment_term.term_date_display))
    end

    it "shows the missing-details explanation and credit hours helper text" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(page_content).to have_text(I18n.t("activities.education.term_credit_hours.body"))
      expect(page_content).to have_field(I18n.t("activities.education.add_your_term.edit.credit_hours"))
      expect(page_content).to have_text(I18n.t("activities.education.add_your_term.edit.credit_hours_hint"))
      expect(page_content).to have_no_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"))
    end

    it "does not show checkbox for a single term" do
      get :edit, params: { education_id: education_activity.id, id: 0 }

      expect(response.body).not_to include("no_hours")
    end

    it "threads from_review and from_edit in the form action" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1 }

      expect(response.body).to include("from_review=1")
      expect(response.body).to include("from_edit=1")
    end

    it "shows Save changes button when from_review is present" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1 }

      expect(page_content).to have_button(I18n.t("activities.hub.save"))
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
      enrollment_term.update!(enrollment_status: "half_time")
      result = ActivityFlowProgressCalculator::OverallResult.new(
        total_hours: 0,
        meets_requirements: false,
        meets_routing_requirements: false
      )
      calculator = instance_double(ActivityFlowProgressCalculator, overall_result: result)
      allow(ActivityFlowProgressCalculator).to receive(:new).and_return(calculator)

      expect(EventTrackingJob).not_to receive(:perform_later)

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

  describe "GET #edit with mixed enrollment statuses" do
    before do
      create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        school_name: "Pine Valley College")
    end

    it "shows checkbox when half-time and less-than-half-time terms are both present" do
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

    it "sets back_url to review when from_review is present" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: education_activity)
      )
    end

    it "threads from_edit in back_url when from_review is present" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1 }

      expect(assigns(:back_url)).to eq(
        review_activities_flow_education_path(id: education_activity, from_edit: 1)
      )
    end
  end

  describe "PATCH #update" do
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) do
      patch :update, params: { education_id: education_activity.id, id: 0, nsc_enrollment_term: { credit_hours: 4 } }
    end

    context "when NSC is disabled" do
      it "redirects to the self-attestation new path" do
        stub_environment_variable("NSC_DISABLED", "true") do
          patch :update, params: { education_id: education_activity.id, id: 0, nsc_enrollment_term: { credit_hours: 4 } }

          expect(response).to redirect_to(new_activities_flow_education_path)
        end
      end
    end

    it_behaves_like "tracks an event", TrackEvent::EducationTermCreditHoursSubmitted,
      extra_attributes: -> { { education_activity_id: kind_of(Integer), term_index: 0, term_date_range: kind_of(String) } }

    context "when validation fails" do
      let(:perform_tracked_action) do
        patch :update, params: { education_id: education_activity.id, id: 0, nsc_enrollment_term: { credit_hours: 0 } }
      end

      it_behaves_like "tracks an event", TrackEvent::EducationTermCreditHoursValidationFailed,
        extra_attributes: -> {
          { education_activity_id: kind_of(Integer), term_index: 0, term_date_range: kind_of(String), error_fields: [ "credit_hours" ] }
        }
    end

    it "saves credit_hours on the NscEnrollmentTerm" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        nsc_enrollment_term: { credit_hours: 4 }
      }

      expect(enrollment_term.reload.credit_hours).to eq(4)
    end

    it "persists decimal credit_hours" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        nsc_enrollment_term: { credit_hours: "2.5" }
      }

      expect(enrollment_term.reload.credit_hours).to eq(BigDecimal("2.5"))
    end

    it "renders an error when no credit hours are entered for a single term" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        no_hours: "1",
        nsc_enrollment_term: { credit_hours: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activities.education.term_credit_hours.error_heading"))
      expect(response.body).to include(I18n.t("activities.education.term_credit_hours.error_body_multi_month"))
      expect(response.body).to include(I18n.t("activities.education.term_credit_hours.field_error"))
      expect(enrollment_term.reload.credit_hours).to be_nil
    end

    it "renders an error when 0 credit hours are entered for a single term" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        nsc_enrollment_term: { credit_hours: 0 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(enrollment_term.reload.credit_hours).to be_nil
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

    it "preserves the hub edit context when continuing to document upload" do
      patch :update, params: { education_id: education_activity.id, id: 0, from_edit: 1, nsc_enrollment_term: { credit_hours: 4 } }

      expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity, from_edit: 1))
    end

    context "with multiple terms" do
      let(:second_enrollment_term) {
        range = activity_flow.reporting_window_range

        create(:nsc_enrollment_term, :less_than_half_time,
          education_activity: education_activity,
          school_name: "State University",
          term_begin: range.begin + 3.months,
          term_end: range.end)
      }
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
        second_enrollment_term
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

      it "saves 0 when no_hours checkbox is selected before the final term" do
        patch :update, params: {
          education_id: education_activity.id,
          id: 0,
          no_hours: "1",
          nsc_enrollment_term: { credit_hours: "" }
        }

        expect(response).to redirect_to(
          edit_activities_flow_education_term_credit_hour_path(
            education_id: education_activity, id: 1
          )
        )
        expect(enrollment_term.reload.credit_hours).to eq(0)
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

      it "renders an error on the final term when all terms have 0 credit hours" do
        enrollment_term.update!(credit_hours: 0)

        patch :update, params: {
          education_id: education_activity.id,
          id: 1,
          no_hours: "1",
          nsc_enrollment_term: { credit_hours: "" }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("activities.education.term_credit_hours.error_heading"))
        expect(response.body).to include(I18n.t("activities.education.term_credit_hours.error_body_multi_month"))
        expect(response.body).to include(I18n.t("activities.education.term_credit_hours.field_error"))
        expect(second_enrollment_term.reload.credit_hours).to be_nil
      end

      it "redirects to document upload on the final term when a previous term has credit hours" do
        enrollment_term.update!(credit_hours: 4)

        patch :update, params: {
          education_id: education_activity.id,
          id: 1,
          no_hours: "1",
          nsc_enrollment_term: { credit_hours: "" }
        }

        expect(response).to redirect_to(
          new_activities_flow_education_document_upload_path(education_id: education_activity)
        )
        expect(second_enrollment_term.reload.credit_hours).to eq(0)
      end
    end

    it "redirects back to review when from_review is present" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        from_review: 1,
        nsc_enrollment_term: { credit_hours: 4 }
      }

      expect(response).to redirect_to(
        review_activities_flow_education_path(id: education_activity)
      )
    end

    it "threads from_edit when redirecting back to review from from_review flow" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        from_review: 1,
        from_edit: 1,
        nsc_enrollment_term: { credit_hours: 4 }
      }

      expect(response).to redirect_to(
        review_activities_flow_education_path(id: education_activity, from_edit: 1)
      )
    end

    it "renders an error when from_review edit leaves all terms with 0 credit hours" do
      patch :update, params: {
        education_id: education_activity.id,
        id: 0,
        from_review: 1,
        no_hours: "1",
        nsc_enrollment_term: { credit_hours: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activities.education.term_credit_hours.error_heading"))
      expect(enrollment_term.reload.credit_hours).to be_nil
    end
  end

  context "when NSC reports enrolled" do
    let(:enrollment_status) { "enrolled" }

    describe "GET #edit" do
      before { get :edit, params: { education_id: education_activity.id, id: 0 } }

      it "shows the self-attested enrollment options" do
        expect(page_content).to have_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"),
          options: [ I18n.t("activities.education.add_your_term.edit.select_one") ] + EducationActivity::SELF_ATTESTED_ENROLLMENT_STATUSES.map { |status| I18n.t("activities.education.add_your_term.edit.enrollment_status_options.#{status}") })
        expect(page_content).to have_selector('[data-education-term-target="creditHours"][hidden]', visible: :all)
      end
    end

    context "when editing saved details" do
      before do
        enrollment_term.update!(supplemental_enrollment_status: "unknown", credit_hours: 2.5)
        get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1 }
      end

      it "restores the supplemental status and fractional hours" do
        expect(page_content).to have_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"),
          selected: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"))
        expect(page_content).to have_field(I18n.t("activities.education.add_your_term.edit.credit_hours"), with: "2.5")
        expect(page_content).to have_button(I18n.t("activities.hub.save"))
      end
    end

    describe "supplemental validation tracking" do
      let(:tracked_flow) { activity_flow }
      let(:perform_tracked_action) do
        patch :update, params: { education_id: education_activity.id, id: 0, nsc_enrollment_term: { supplemental_enrollment_status: "", credit_hours: 4 } }
      end

      it_behaves_like "tracks an event", TrackEvent::EducationTermCreditHoursValidationFailed,
        extra_attributes: -> {
          { education_activity_id: kind_of(Integer), term_index: 0, term_date_range: kind_of(String), error_fields: [ "supplemental_enrollment_status" ] }
        }
    end

    describe "PATCH #update" do
      let(:supplemental_status) { "half_time" }
      let(:submitted_hours) { "4" }
      let(:submitted_details) { { supplemental_enrollment_status: supplemental_status, credit_hours: submitted_hours } }

      before do
        patch :update, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1, nsc_enrollment_term: submitted_details }
      end

      it "saves the supplemental status separately and returns to review" do
        expect(enrollment_term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "half_time", credit_hours: nil)
        expect(response).to redirect_to(review_activities_flow_education_path(id: education_activity, from_edit: 1))
      end

      context "with less-than-half-time enrollment" do
        let(:supplemental_status) { "less_than_half_time" }
        let(:submitted_hours) { "2.5" }

        it "saves the reported status and fractional hours" do
          expect(enrollment_term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "less_than_half_time", credit_hours: BigDecimal("2.5"))
          expect(response).to have_http_status(:redirect)
        end
      end

      context "when the applicant is unsure" do
        let(:supplemental_status) { "unknown" }

        it "saves the reported credit hours" do
          expect(enrollment_term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "unknown", credit_hours: 4)
          expect(response).to have_http_status(:redirect)
        end
      end

      context "without a supplemental status" do
        let(:supplemental_status) { "" }

        it "renders the enrollment error on the form" do
          expect(response).to have_http_status(:unprocessable_content)
          expect(page_content).to have_selector("select[aria-invalid='true']")
          expect(page_content).to have_text(I18n.t("activerecord.errors.models.nsc_enrollment_term.attributes.supplemental_enrollment_status.inclusion"))
        end
      end

      context "with missing hours for less-than-half-time enrollment" do
        let(:supplemental_status) { "less_than_half_time" }
        let(:submitted_hours) { "" }

        it "keeps the selected enrollment status when rendering the hours error" do
          expect(response).to have_http_status(:unprocessable_content)
          expect(page_content).to have_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"),
            selected: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"))
          expect(page_content).to have_text(I18n.t("activities.education.term_credit_hours.field_error"))
        end
      end
    end
  end

  describe "PATCH #update with multiple enrolled terms" do
    let(:enrollment_status) { "enrolled" }
    let!(:second_term) { create(:nsc_enrollment_term, :enrolled, education_activity: education_activity) }

    before do
      enrollment_term.update!(supplemental_enrollment_status: "full_time")
      patch :update, params: { education_id: education_activity.id, id: 1, no_hours: "1", nsc_enrollment_term: { credit_hours: "" } }
    end

    it "accepts a term without classes when another term has sufficient supplemental enrollment" do
      expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity))
      expect(second_term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: nil, credit_hours: 0)
      expect(enrollment_term.reload.supplemental_enrollment_status).to eq("full_time")
    end
  end

  describe "PATCH #update with invalid credit hours" do
    let(:submitted_hours) { "-1" }

    before do
      patch :update, params: { education_id: education_activity.id, id: 0, nsc_enrollment_term: { credit_hours: submitted_hours } }
    end

    it "rejects negative hours" do
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_content).to have_selector("input[aria-invalid='true']")
      expect(enrollment_term.reload.credit_hours).to be_nil
    end

    context "with nonnumeric hours" do
      let(:submitted_hours) { "abc" }

      it "rejects nonnumeric hours" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(page_content).to have_selector("input[aria-invalid='true']")
      end
    end
  end
end
