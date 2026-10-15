require "rails_helper"

RSpec.describe Activities::Education::AddYourTermController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(:activity_flow,
      activity_flow_invitation: create(:activity_flow_invitation),
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 3)
  end
  let(:education_activity) do
    create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested,
      school_name: "Test University", credit_hours: nil, draft: true)
  end
  let(:term_start) { activity_flow.reporting_months.first }
  let(:term_end) { activity_flow.reporting_months.last }
  let(:rendered) { Capybara.string(response.body) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) { get :edit, params: { education_id: education_activity.id } }

    it_behaves_like "tracks an event", TrackEvent::EducationAddTermViewed,
      extra_attributes: -> { { education_activity_id: kind_of(Integer), term_date_range: nil, enrollment_status: nil } }

    context "when editing from review" do
      let(:perform_tracked_action) { get :edit, params: { education_id: education_activity.id, from_review: 1, from_edit: 1 } }

      it_behaves_like "tracks an event", TrackEvent::EducationAddTermViewed,
        extra_attributes: -> { { from_review: "1", from_edit: "1" } }
    end

    it "renders the school, reporting period, and term instructions" do
      get :edit, params: { education_id: education_activity.id }

      expect(rendered).to have_selector("h1", text: I18n.t("activities.education.add_your_term.edit.title", school_name: education_activity.school_name))
      expect(rendered).to have_text(activity_flow.reporting_window_display)
      expect(rendered).to have_selector("p", text: I18n.t("activities.education.add_your_term.edit.description", school_name: education_activity.school_name), exact_text: true)
      expect(rendered).to have_selector("p", text: I18n.t("activities.education.add_your_term.edit.multiple_terms_description"), exact_text: true)
    end

    it "identifies the term dates and enrollment status as required" do
      get :edit, params: { education_id: education_activity.id }

      expect(rendered).to have_selector("input[name='education_activity[self_attested_term_start]'][required]")
      expect(rendered).to have_selector("input[name='education_activity[self_attested_term_end]'][required]")
      expect(rendered).to have_selector("select[name='education_activity[self_attested_enrollment_status]'][required]")
    end

    it "links back to school information" do
      get :edit, params: { education_id: education_activity.id }

      expect(assigns(:back_url)).to eq(edit_activities_flow_education_path(id: education_activity))
    end

    it "preserves review navigation in the back link and form action" do
      get :edit, params: { education_id: education_activity.id, from_review: 1, from_edit: 1 }

      expect(assigns(:back_url)).to eq(review_activities_flow_education_path(id: education_activity, from_edit: 1))
      expect(rendered).to have_selector("form[action='#{activities_flow_education_add_your_term_path(education_id: education_activity, from_review: 1, from_edit: 1)}']")
    end

    it "prefills saved dates, enrollment status, and fractional credits" do
      education_activity.update!(self_attested_term_start: term_start, self_attested_term_end: term_end,
        self_attested_enrollment_status: "less_than_half_time", credit_hours: 3.5)

      get :edit, params: { education_id: education_activity.id }

      expect(rendered).to have_field(I18n.t("activities.education.add_your_term.edit.term_start"), with: term_start.strftime("%m/%Y"))
      expect(rendered).to have_field(I18n.t("activities.education.add_your_term.edit.term_end"), with: term_end.strftime("%m/%Y"))
      expect(rendered).to have_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"),
        selected: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"))
      expect(rendered).to have_field(I18n.t("activities.education.add_your_term.edit.credit_hours"), with: controller.view_context.decimal_input_value(education_activity.credit_hours))
    end

    it "scopes the activity to the current flow" do
      other_activity = create(:education_activity)

      expect {
        get :edit, params: { education_id: other_activity.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "redirects NSC activities to the activity hub" do
      education_activity.update!(data_source: :validated)

      get :edit, params: { education_id: education_activity.id }

      expect(response).to redirect_to(activities_flow_root_path)
    end
  end

  describe "PATCH #update" do
    subject(:submit_term) { patch :update, params: submission_params }

    let(:term_attributes) do
      {
        self_attested_term_start: term_start.strftime("%m/%Y"),
        self_attested_term_end: term_end.strftime("%m/%Y"),
        self_attested_enrollment_status: "less_than_half_time",
        credit_hours: "3.5"
      }
    end
    let(:submission_params) { { education_id: education_activity.id, education_activity: term_attributes } }
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) { submit_term }
    let(:term_start_group) { rendered.find(".usa-form-group", text: I18n.t("activities.education.add_your_term.edit.term_start")) }
    let(:term_end_group) { rendered.find(".usa-form-group", text: I18n.t("activities.education.add_your_term.edit.term_end")) }
    let(:enrollment_status_group) { rendered.find(".usa-form-group", text: I18n.t("activities.education.add_your_term.edit.enrollment_status")) }

    it_behaves_like "tracks an event", TrackEvent::EducationAddTermSubmitted,
      extra_attributes: -> { { education_activity_id: kind_of(Integer), term_date_range: kind_of(String), enrollment_status: "less_than_half_time" } }

    context "with valid term details" do
      before { submit_term }

      it "saves a self-attested term and fractional credits" do
        expect(education_activity.reload).to have_attributes(
          self_attested_term_start: term_start,
          self_attested_term_end: term_end,
          self_attested_enrollment_status: "less_than_half_time",
          credit_hours: 3.5,
          draft: true
        )
      end

      it "continues to document upload" do
        expect(response).to redirect_to(new_activities_flow_education_document_upload_path(education_id: education_activity))
      end

      it "keeps the manual term separate from NSC records" do
        expect(education_activity.nsc_enrollment_terms).to be_empty
      end
    end

    context "when editing from review" do
      let(:submission_params) { super().merge(from_review: 1, from_edit: 1) }

      it "continues to upload with the navigation context" do
        submit_term

        expect(response).to redirect_to(new_activities_flow_education_document_upload_path(
          education_id: education_activity, from_review: 1, from_edit: 1))
      end
    end

    context "with full-time enrollment" do
      let(:term_attributes) { super().merge(self_attested_enrollment_status: "full_time") }

      it "saves enrollment without credits" do
        submit_term

        expect(education_activity.reload).to have_attributes(self_attested_enrollment_status: "full_time", credit_hours: nil)
        expect(response).to have_http_status(:found)
      end
    end

    context "with half-time enrollment" do
      let(:term_attributes) { super().merge(self_attested_enrollment_status: "half_time") }

      it "saves enrollment without credits" do
        submit_term

        expect(education_activity.reload).to have_attributes(self_attested_enrollment_status: "half_time", credit_hours: nil)
        expect(response).to have_http_status(:found)
      end
    end

    context "when enrollment is unknown" do
      let(:term_attributes) { super().merge(self_attested_enrollment_status: "unknown", credit_hours: "") }

      it "allows optional credits to be blank" do
        submit_term

        expect(education_activity.reload).to have_attributes(self_attested_enrollment_status: "unknown", credit_hours: nil)
        expect(response).to have_http_status(:found)
      end
    end

    context "when all required fields are blank" do
      let(:term_attributes) { { self_attested_term_start: "", self_attested_term_end: "", self_attested_enrollment_status: "" } }

      it_behaves_like "tracks an event", TrackEvent::EducationAddTermValidationFailed,
        extra_attributes: -> {
          { education_activity_id: kind_of(Integer), term_date_range: nil, enrollment_status: "",
            error_fields: contain_exactly("self_attested_enrollment_status", "self_attested_term_start", "self_attested_term_end") }
        }

      it "renders the required-field alert, inline date errors, and enrollment highlight" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_text(I18n.t("activities.education.add_your_term.errors.information_heading"))
        expect(rendered).to have_text(I18n.t("activities.education.add_your_term.errors.information_body"))
        expect(term_start_group).to have_selector(".usa-error-message", text: I18n.t("activerecord.errors.models.education_activity.attributes.self_attested_term_start.blank"))
        expect(term_end_group).to have_selector(".usa-error-message", text: I18n.t("activerecord.errors.models.education_activity.attributes.self_attested_term_end.blank"))
        expect(enrollment_status_group).to have_selector("select.usa-input--error.text-error[aria-invalid='true']")
        expect(enrollment_status_group).to have_no_selector(".usa-error-message")
      end
    end

    context "with an invalid month" do
      let(:term_attributes) { super().merge(self_attested_term_start: "55/2026") }

      before { submit_term }

      it "renders the invalid-date alert and preserves the input" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_text(I18n.t("activities.education.add_your_term.errors.dates_heading"))
        expect(rendered).to have_text(I18n.t("activities.education.add_your_term.errors.dates_body"))
        expect(term_start_group).to have_selector(".usa-error-message", text: I18n.t("activerecord.errors.models.education_activity.attributes.self_attested_term_start.invalid"))
        expect(rendered).to have_field(I18n.t("activities.education.add_your_term.edit.term_start"), with: "55/2026")
      end

      it "leaves the saved activity unchanged" do
        expect(education_activity.reload).to have_attributes(self_attested_term_start: nil, self_attested_term_end: nil, self_attested_enrollment_status: nil)
      end
    end

    context "with a date in a different format" do
      let(:term_attributes) { super().merge(self_attested_term_start: term_start.iso8601) }

      it "requires MM/YYYY input" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(term_start_group).to have_selector(".usa-error-message", text: I18n.t("activerecord.errors.models.education_activity.attributes.self_attested_term_start.invalid"))
      end
    end

    context "when the end is before the start" do
      let(:term_attributes) { super().merge(self_attested_term_end: (term_start - 1.month).strftime("%m/%Y")) }

      it "renders the invalid-date error for the end date" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(term_end_group).to have_selector(".usa-error-message", text: I18n.t("activerecord.errors.models.education_activity.attributes.self_attested_term_end.invalid"))
      end
    end

    context "when the start and end are the same month" do
      let(:term_attributes) { super().merge(self_attested_term_end: term_start.strftime("%m/%Y")) }

      it "requires the start to be before the end" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_text(I18n.t("activities.education.add_your_term.errors.dates_heading"))
      end
    end

    context "with an unsupported enrollment status" do
      let(:term_attributes) { super().merge(self_attested_enrollment_status: "three_quarter_time") }

      it "highlights the enrollment selector without an inline message" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(enrollment_status_group).to have_selector("select.usa-input--error.text-error[aria-invalid='true']")
        expect(enrollment_status_group).to have_no_selector(".usa-error-message")
      end
    end

    context "with nonnumeric credits" do
      let(:term_attributes) { super().merge(credit_hours: "abc") }

      it "renders the credit validation error" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_selector(".usa-error-message", text: I18n.t("errors.messages.not_a_number"))
      end
    end

    context "with negative credits" do
      let(:term_attributes) { super().merge(credit_hours: "-1") }

      it "renders the credit validation error" do
        submit_term

        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_selector(".usa-error-message", text: I18n.t("errors.messages.greater_than_or_equal_to", count: 0))
      end
    end
  end
end
