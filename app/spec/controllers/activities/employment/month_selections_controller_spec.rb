require "rails_helper"

RSpec.describe Activities::Employment::MonthSelectionsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(
      :activity_flow,
      activity_flow_invitation: create(:activity_flow_invitation),
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 3
    )
  end
  let(:employment_activity) { create(:employment_activity, activity_flow: activity_flow) }
  let(:reporting_months) { activity_flow.reporting_months.map(&:beginning_of_month) }
  let(:tracked_flow) { activity_flow }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
    let(:perform_tracked_action) { get :edit, params: { employment_id: employment_activity.id } }

    context "with an employment-focused flow" do
      before { activity_flow.update!(employment_focused: true) }

      it "asks for paid months only" do
        get :edit, params: { employment_id: employment_activity.id }

        expect(Capybara.string(response.body)).to have_text(
          I18n.t("activities.employment.month_selections.edit.employment_focused.description")
        )
      end
    end

    it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionViewed,
      extra_attributes: -> { { employment_activity_id: employment_activity.id } }

    context "when from_edit and from_review are present" do
      let(:perform_tracked_action) do
        get :edit, params: { employment_id: employment_activity.id, from_edit: 1, from_review: 1 }
      end

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionViewed,
        extra_attributes: -> { { employment_activity_id: employment_activity.id, from_edit: "1", from_review: "1" } }
    end

    context "when work is unpaid or in-kind" do
      let(:employment_activity) do
        create(:employment_activity, activity_flow: activity_flow, compensation_type: :unpaid_or_in_kind)
      end

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionViewed,
        extra_attributes: -> { { employment_activity_id: employment_activity.id } }
    end

    context "with a one-month tokenized renewal" do
      before do
        activity_flow.update!(reporting_window_type: "renewal", reporting_window_months: 1)
      end

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionViewed,
        extra_attributes: -> { { employment_activity_id: employment_activity.id } }
    end

    it "renders the page content and reporting-period months" do
      get :edit, params: { employment_id: employment_activity.id }

      rendered = Capybara.string(response.body)
      expect(response).to have_http_status(:ok)
      expect(rendered).to have_text(
        I18n.t(
          "activities.employment.month_selections.edit.title",
          employer_name: employment_activity.employer_name
        )
      )
      expect(rendered).to have_text(I18n.t("activities.hub.empty_state_reporting_period_label"))
      expect(rendered).to have_text(activity_flow.reporting_window_display)
      expect(rendered).to have_text(I18n.t("activities.employment.month_selections.edit.paid_description"))
      reporting_months.each do |month|
        expect(rendered).to have_field(I18n.l(month, format: :month_year), type: "checkbox", visible: :all)
      end
    end

    it "asks for hours for unpaid or in-kind work" do
      employment_activity.update!(compensation_type: :unpaid_or_in_kind)

      get :edit, params: { employment_id: employment_activity.id }

      rendered = Capybara.string(response.body)
      expect(rendered).to have_text(
        I18n.t("activities.employment.month_selections.edit.unpaid_or_in_kind_description")
      )
    end

    it "checks previously selected months" do
      employment_activity.update!(selected_months: [ reporting_months.second ])

      get :edit, params: { employment_id: employment_activity.id }

      rendered = Capybara.string(response.body)
      expect(rendered).to have_field(
        I18n.l(reporting_months.second, format: :month_year),
        checked: true,
        visible: :all
      )
      expect(rendered).to have_field(
        I18n.l(reporting_months.first, format: :month_year),
        checked: false,
        visible: :all
      )
    end

    it "links back to employer information" do
      get :edit, params: { employment_id: employment_activity.id }

      expect(Capybara.string(response.body)).to have_link(
        I18n.t("activities.activity_header_component.back"),
        href: edit_activities_flow_income_employment_path(id: employment_activity)
      )
    end

    it "preserves from_edit in the form action" do
      get :edit, params: { employment_id: employment_activity.id, from_edit: 1 }

      expect(response.body).to include("from_edit=1")
    end

    it "redirects generic flows to the existing first-month page" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      generic_flow = create(:activity_flow, activity_flow_invitation: nil, reporting_window_months: 3)
      generic_activity = create(:employment_activity, activity_flow: generic_flow)
      session[:flow_id] = generic_flow.id

      get :edit, params: { employment_id: generic_activity.id }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: generic_activity, id: 0)
      )
    end

    it "redirects one-month tokenized applications to the first-month page" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      one_month_flow = create(
        :activity_flow,
        activity_flow_invitation: create(:activity_flow_invitation),
        reporting_window_type: "application",
        reporting_window_months: 1
      )
      one_month_activity = create(:employment_activity, activity_flow: one_month_flow)
      session[:flow_id] = one_month_flow.id

      get :edit, params: { employment_id: one_month_activity.id }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: one_month_activity, id: 0)
      )
    end
  end

  describe "PATCH #update" do
    let(:submitted_months) do
      [ "", reporting_months.third.iso8601, reporting_months.first.iso8601,
        reporting_months.third.iso8601, Date.current.beginning_of_month.iso8601 ]
    end
    let(:navigation_params) { {} }
    let(:perform_tracked_action) do
      patch :update, params: {
        employment_id: employment_activity.id,
        employment_activity: { selected_months: submitted_months },
        **navigation_params
      }
    end
    let(:submission_attributes) do
      {
        employment_activity_id: employment_activity.id,
        selected_months: [
          I18n.l(reporting_months.first, format: :month_year),
          I18n.l(reporting_months.third, format: :month_year)
        ]
      }
    end

    it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionSubmitted,
      extra_attributes: -> { submission_attributes }

    context "when from_edit and from_review are present" do
      let(:navigation_params) { { from_edit: 1, from_review: 1 } }

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionSubmitted,
        extra_attributes: -> { submission_attributes.merge(from_edit: "1", from_review: "1") }
    end

    context "when work is unpaid or in-kind" do
      let(:employment_activity) do
        create(:employment_activity, activity_flow: activity_flow, compensation_type: :unpaid_or_in_kind)
      end

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSelectionSubmitted,
        extra_attributes: -> { submission_attributes }
    end

    it "saves selected months chronologically and redirects to the earliest selection" do
      patch :update, params: {
        employment_id: employment_activity.id,
        employment_activity: {
          selected_months: [ reporting_months.third.iso8601, reporting_months.first.iso8601 ]
        }
      }

      expect(employment_activity.reload.selected_months).to eq([
        reporting_months.first,
        reporting_months.third
      ])
      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0)
      )
    end

    it "removes data for months that are no longer selected" do
      first_record = create(
        :employment_activity_month,
        employment_activity: employment_activity,
        month: reporting_months.first
      )
      second_record = create(
        :employment_activity_month,
        employment_activity: employment_activity,
        month: reporting_months.second
      )

      patch :update, params: {
        employment_id: employment_activity.id,
        employment_activity: { selected_months: [ reporting_months.second.iso8601 ] }
      }

      expect(EmploymentActivityMonth.exists?(first_record.id)).to be false
      expect(EmploymentActivityMonth.exists?(second_record.id)).to be true
    end

    it "requires at least one selected month" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      patch :update, params: {
        employment_id: employment_activity.id,
        employment_activity: { selected_months: [ "" ] }
      }

      rendered = Capybara.string(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(rendered).to have_text(
        I18n.t("activities.employment.month_selections.edit.error_heading")
      )
      expect(employment_activity.reload.selected_months).to be_empty
    end

    it "ignores months outside the reporting period" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      patch :update, params: {
        employment_id: employment_activity.id,
        employment_activity: { selected_months: [ Date.current.beginning_of_month.iso8601 ] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(employment_activity.reload.selected_months).to be_empty
    end

    it "preserves from_edit in the monthly-page redirect" do
      patch :update, params: {
        employment_id: employment_activity.id,
        from_edit: 1,
        employment_activity: { selected_months: [ reporting_months.second.iso8601 ] }
      }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(
          employment_id: employment_activity,
          id: 0,
          from_edit: 1
        )
      )
    end
  end
end
