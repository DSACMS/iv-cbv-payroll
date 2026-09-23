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
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) { get :edit, params: { employment_id: employment_activity.id, id: 0 } }

    it_behaves_like "tracks an event", TrackEvent::EmploymentMonthViewed,
      extra_attributes: -> { { employment_activity_id: kind_of(Integer), month_index: 0, month: kind_of(String) } }

    it "redirects to month 0 for an out-of-range month index" do
      get :edit, params: { employment_id: employment_activity.id, id: 99 }

      expect(response).to redirect_to(
        edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 0)
      )
    end

    it "does not track an event for an out-of-range month index" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      get :edit, params: { employment_id: employment_activity.id, id: 99 }
    end

    it "renders the gross income currency field" do
      get :edit, params: { employment_id: employment_activity.id, id: 0 }

      expect(response.body).to include("usa-input-prefix")
    end

    context "with selected months" do
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

      it "renders the selected month's monthly details" do
        first_month, second_month, third_month = activity_flow.reporting_months
        employment_activity.update!(selected_months: [ third_month, first_month ])

        get :edit, params: { employment_id: employment_activity.id, id: 1 }

        rendered = Capybara.string(response.body)
        expect(rendered).to have_selector(
          "h1",
          text: I18n.t(
            "activities.employment.hours_input.heading",
            organization: employment_activity.employer_name
          ),
          exact_text: true,
          normalize_ws: true
        )
        expect(rendered).to have_text(
          [
            I18n.t(
              "activities.employment.hours_input.month_indicator",
              current: 2,
              total: 2
            ),
            I18n.l(third_month, format: :month)
          ].join(" "),
          normalize_ws: true
        )
        expect(rendered).to have_field(
          I18n.t(
            "activities.employment.hours_input.gross_income_label",
            month: I18n.l(third_month, format: :month)
          )
        )
        expect(rendered).to have_no_selector('input[name="no_hours"]', visible: :all)
        expect(rendered).to have_no_text(I18n.l(third_month, format: :month_year))
        expect(rendered).to have_no_text(I18n.l(second_month, format: :month))
      end

      it "renders the month indicator when one month is selected" do
        selected_month = activity_flow.reporting_months.second
        employment_activity.update!(selected_months: [ selected_month ])

        get :edit, params: { employment_id: employment_activity.id, id: 0 }

        expect(Capybara.string(response.body)).to have_text(
          [
            I18n.t(
              "activities.employment.hours_input.month_indicator",
              current: 1,
              total: 1
            ),
            I18n.l(selected_month, format: :month)
          ].join(" "),
          normalize_ws: true
        )
      end

      it "redirects to month selection when no months have been selected, even with saved month data" do
        create(
          :employment_activity_month,
          employment_activity: employment_activity,
          month: activity_flow.reporting_months.first
        )

        get :edit, params: { employment_id: employment_activity.id, id: 0 }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_selection_path(employment_id: employment_activity)
        )
      end
    end
  end

  describe "PATCH #update" do
    let(:tracked_flow) { activity_flow }
    let(:perform_tracked_action) do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }
    end

    it_behaves_like "tracks an event", TrackEvent::EmploymentMonthSubmitted,
      extra_attributes: -> { { employment_activity_id: kind_of(Integer), month_index: 0, month: kind_of(String) } }

    context "when validation fails" do
      let(:perform_tracked_action) do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: "", hours: "" }
        }
      end

      it_behaves_like "tracks an event", TrackEvent::EmploymentMonthValidationFailed,
        extra_attributes: -> {
          { employment_activity_id: kind_of(Integer), month_index: 0, month: kind_of(String), error_fields: [ "gross_income", "hours" ] }
        }
    end

    it "does not track an event for an out-of-range month index" do
      expect(EventTrackingJob).not_to receive(:perform_later)

      patch :update, params: {
        employment_id: employment_activity.id,
        id: 99,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }
    end

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

    it "redirects back to review when from_review is set" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        from_review: 1,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }

      expect(response).to redirect_to(review_activities_flow_income_employment_path(id: employment_activity))
    end

    it "passes validation when only income is provided" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: 100, hours: 0 }
      }

      expect(response).to redirect_to(new_activities_flow_income_employment_document_upload_path(employment_id: employment_activity))
    end

    it "passes validation when only hours are provided" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: 0, hours: 10 }
      }

      expect(response).to redirect_to(new_activities_flow_income_employment_document_upload_path(employment_id: employment_activity))
    end

    it "rejects zero as the only entered value" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: 0, hours: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects negative income when hours are positive" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: -1, hours: 10 }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "threads from_edit to review when from_review is set" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        from_review: 1,
        from_edit: 1,
        employment_activity_month: { gross_income: 339, hours: 45 }
      }

      expect(response).to redirect_to(
        review_activities_flow_income_employment_path(id: employment_activity, from_edit: 1)
      )
    end

    context "with selected months" do
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

      before do
        first_month, _second_month, third_month = activity_flow.reporting_months
        employment_activity.update!(selected_months: [ third_month, first_month ])
      end

      it "advances directly to the next selected month" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: 100, hours: 10 }
        }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 1)
        )
      end

      it "shows the error alert when income and hours are blank" do
        first_month = activity_flow.reporting_months.first

        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: "", hours: "" }
        }

        rendered = Capybara.string(response.body)
        expect(response).to have_http_status(:unprocessable_content)
        expect(rendered).to have_text(I18n.t("activities.employment.hours_input.error_heading"))
        expect(rendered).to have_text(
          I18n.t("activities.employment.hours_input.error_body")
        )
        gross_income_label = I18n.t(
          "activities.employment.hours_input.gross_income_label",
          month: I18n.l(first_month, format: :month)
        )
        expect(rendered.find_field(gross_income_label).value).to be_nil
        expect(rendered).to have_no_selector(".usa-error-message")
      end

      context "when validation fails" do
        let(:perform_tracked_action) do
          patch :update, params: {
            employment_id: employment_activity.id,
            id: 0,
            employment_activity_month: { gross_income: "", hours: "" }
          }
        end

        it_behaves_like "tracks an event", TrackEvent::EmploymentMonthValidationFailed,
          extra_attributes: -> {
            {
              employment_activity_id: kind_of(Integer),
              month_index: 0,
              month: kind_of(String),
              error_fields: [ "gross_income", "hours" ]
            }
          }
      end

      it "advances when only income is entered" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: 100, hours: "" }
        }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 1)
        )
      end

      it "advances when only hours are entered" do
        patch :update, params: {
          employment_id: employment_activity.id,
          id: 0,
          employment_activity_month: { gross_income: "", hours: 10 }
        }

        expect(response).to redirect_to(
          edit_activities_flow_income_employment_month_path(employment_id: employment_activity, id: 1)
        )
      end

      it "saves the month represented by the selected-month index" do
        third_month = activity_flow.reporting_months.third

        patch :update, params: {
          employment_id: employment_activity.id,
          id: 1,
          employment_activity_month: { gross_income: 100, hours: 10 }
        }

        expect(employment_activity.employment_activity_months.last.month).to eq(third_month)
      end
    end

    it "persists decimal hours and gross_income" do
      patch :update, params: {
        employment_id: employment_activity.id,
        id: 0,
        employment_activity_month: { gross_income: "1234.56", hours: "2.5" }
      }

      month = employment_activity.activity_months.last
      expect(month.gross_income).to eq(BigDecimal("1234.56"))
      expect(month.hours).to eq(BigDecimal("2.5"))
    end
  end
end
