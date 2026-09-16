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

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #edit" do
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
      expect(rendered).to have_text(I18n.t("activities.employment.month_selections.edit.description"))
      reporting_months.each do |month|
        expect(rendered).to have_field(I18n.l(month, format: :month_year), type: "checkbox", visible: :all)
      end
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
      generic_flow = create(:activity_flow, activity_flow_invitation: nil, reporting_window_months: 3)
      generic_activity = create(:employment_activity, activity_flow: generic_flow)
      session[:flow_id] = generic_flow.id

      get :edit, params: { employment_id: generic_activity.id }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: generic_activity, id: 0)
      )
    end

    it "redirects one-month tokenized applications to the first-month page" do
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
