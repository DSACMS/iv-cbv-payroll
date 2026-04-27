require "rails_helper"

RSpec.describe Activities::SummaryController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      job_training_activities_count: 0,
      volunteering_activities_count: 0,
      education_activities_count: 0
    )
  }
  let(:other_flow) { create(:activity_flow) }
  let(:test_confirmation_code) { "SANDBOX123" }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "only shows activities belonging to the current activity flow" do
      visible_volunteering = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Scoped", hours: 1)
      create(:volunteering_activity, activity_flow: other_flow, organization_name: "Ignored", hours: 2)
      visible_job_training = create(:job_training_activity, activity_flow: activity_flow, program_name: "Resume Workshop", organization_address: "123 Main St", hours: 6)
      create(:job_training_activity, activity_flow: other_flow, program_name: "Other Workshop", organization_address: "456 Elm St", hours: 8)

      get :show

      expect(assigns(:community_service_activities)).to contain_exactly(visible_volunteering)
      expect(assigns(:work_programs_activities)).to contain_exactly(visible_job_training)
      expect(response.body).to include("Scoped")
      expect(response.body).to include("Resume Workshop")
    end

    it "builds all_activities list with all activity types" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Org A", hours: 1)
      create(:job_training_activity, activity_flow: activity_flow, program_name: "Program B", organization_address: "123 Main St", hours: 6)
      education_activity = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(:nsc_enrollment_term, education_activity: education_activity, school_name: "Test University")

      get :show

      all_activities = assigns(:all_activities)
      expect(all_activities.length).to eq(3)
      expect(all_activities.map { |a| a[:type] }).to contain_exactly(:community_service, :work_programs, :education)
    end

    it "excludes validated education activities with no enrollment terms from all_activities" do
      create(:education_activity, activity_flow: activity_flow, status: :no_enrollments)
      fully_self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "University of Illinois"
      )
      create(:education_activity_month, education_activity: fully_self_attested_activity, month: activity_flow.reporting_months.first, hours: 6)

      get :show

      education_activities = assigns(:all_activities).select { |activity| activity[:type] == :education }
      expect(education_activities.size).to eq(1)
      expect(education_activities.first[:activity]).to eq(fully_self_attested_activity)
    end

    it "renders community service organization details and monthly hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Habitat for Humanity",
        street_address: "942 W Harlan Ave",
        city: "Gainesville",
        state: "Florida",
        zip_code: "32601",
        coordinator_name: "Donny Murphy",
        coordinator_email: "donny@habitat.com"
      )
      first_month = create(:volunteering_activity_month, volunteering_activity: activity, month: activity_flow.reporting_months.first, hours: 45)
      second_month = create(:volunteering_activity_month, volunteering_activity: activity, month: activity_flow.reporting_months.second, hours: 12)

      get :show

      expect(response.body).to include(activity.organization_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.coordinator_name)
      expect(response.body).to include(activity.coordinator_email)
      expect(response.body).to include(I18n.t("shared.not_applicable"))
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    it "renders work program details and monthly hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :job_training_activity,
        activity_flow: activity_flow,
        organization_name: "Habitat for Humanity",
        program_name: "Resume and Skills Program",
        street_address: "942 W Harlan Ave",
        city: "Gainesville",
        state: "Florida",
        zip_code: "32601",
        contact_name: "Donny Murphy",
        contact_email: "donny@habitat.com",
        contact_phone_number: "555-0100"
      )
      first_month = create(:job_training_activity_month, job_training_activity: activity, month: activity_flow.reporting_months.first, hours: 45)
      second_month = create(:job_training_activity_month, job_training_activity: activity, month: activity_flow.reporting_months.second, hours: 12)

      get :show

      expect(response.body).to include(activity.organization_name)
      expect(response.body).to include(activity.program_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.contact_name)
      expect(response.body).to include(activity.contact_email)
      expect(response.body).to include(activity.contact_phone_number)
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    it "renders fully self-attested education details and monthly credit hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "University of Illinois",
        street_address: "601 E John St",
        city: "Champaign",
        state: "IL",
        contact_name: "Dr. Smith",
        contact_email: "smith@illinois.edu",
        contact_phone_number: "555-1212"
      )
      first_month = create(:education_activity_month, education_activity: activity, month: activity_flow.reporting_months.first, hours: 4)
      second_month = create(:education_activity_month, education_activity: activity, month: activity_flow.reporting_months.second, hours: 6)

      get :show

      expect(response.body).to include(activity.school_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.contact_name)
      expect(response.body).to include(activity.contact_email)
      expect(response.body).to include(activity.contact_phone_number)
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    it "renders partially self-attested education in one table with saved term credit hours" do
      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        first_name: "Ada",
        middle_name: "B",
        last_name: "Lovelace",
        school_name: "River College",
        credit_hours: 9
      )

      get :show

      doc = Capybara.string(response.body)
      expect(doc).to have_selector("table", count: 2) # contact info table + monthly details table
      expect(response.body).to include("Ada B Lovelace")
      expect(response.body).to include("River College")
      expect(response.body).to include(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))

      term_credit_rows = doc.all("table").last.all("tbody tr")
      expect(term_credit_rows.size).to eq(1)
      expect(term_credit_rows.first.all("th, td").last.text.strip).to eq("9")
    end

    it "renders multiple less-than-half-time enrollments from the same school in one collapsed table" do
      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        school_name: "River College",
        term_begin: Date.new(2026, 1, 1),
        term_end: Date.new(2026, 1, 31),
        credit_hours: 3
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        school_name: "River College",
        term_begin: Date.new(2026, 2, 1),
        term_end: Date.new(2026, 2, 28),
        credit_hours: 6
      )

      get :show

      doc = Capybara.string(response.body)
      expect(doc).to have_selector("table", count: 2) # contact info table + monthly details table

      contact_info_rows = doc.all("table").first.all("tbody tr")
      expect(contact_info_rows.filter_map { |row|
        row if row.first("th")&.text&.strip == I18n.t("components.enrollment_term_table_component.school_or_program")
      }.size).to eq(1)
      expect(contact_info_rows.map(&:text).grep(/River College/).size).to eq(1)
      expect(contact_info_rows.filter_map { |row|
        row if row.first("th")&.text&.strip == I18n.t("components.enrollment_term_table_component.enrollment_term")
      }.size).to eq(2)
      expect(contact_info_rows.filter_map { |row|
        row if row.first("th")&.text&.strip == I18n.t("components.enrollment_term_table_component.enrollment_status")
      }.size).to eq(2)

      monthly_details_headers = doc.all("table").last.all("thead th").map { |cell| cell.text.strip }
      expect(monthly_details_headers).to include(I18n.t("components.enrollment_term_table_component.enrollment_status"))
      expect(monthly_details_headers).to include(I18n.t("activities.summary.education.term_credit_hours"))

      term_credit_rows = doc.all("table").last.all("tbody tr")
      expect(term_credit_rows.map { |row| row.all("th, td").last.text.strip }).to eq(%w[3 6])
    end

    it "renders multiple less-than-half-time enrollments from different schools in one table" do
      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        school_name: "River College",
        credit_hours: 3
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        school_name: "Lake Tech",
        credit_hours: 6
      )

      get :show

      doc = Capybara.string(response.body)
      expect(doc).to have_selector("table", count: 2) # contact info table + monthly details table
      expect(response.body).to include("River College")
      expect(response.body).to include("Lake Tech")

      contact_info_rows = doc.all("table").first.all("tbody tr")
      expect(contact_info_rows.filter_map { |row|
        row if row.first("th")&.text&.strip == I18n.t("components.enrollment_term_table_component.school_or_program")
      }.size).to eq(2)

      term_credit_rows = doc.all("table").last.all("tbody tr")
      expect(term_credit_rows.map { |row| row.all("th, td").last.text.strip }).to contain_exactly("3", "6")
    end

    it "renders mixed overlapping statuses and includes all enrollments in the summary" do
      half_time_school_name = "Pine Valley College"
      less_than_half_time_school_name = "Riverside Community College"
      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :validated,
        status: :succeeded
      )
      first_month = activity_flow.reporting_months.first
      second_month = activity_flow.reporting_months.second
      create(
        :nsc_enrollment_term,
        education_activity: activity,
        school_name: half_time_school_name,
        enrollment_status: :half_time,
        term_begin: first_month,
        term_end: second_month.end_of_month
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: activity,
        school_name: less_than_half_time_school_name,
        term_begin: first_month,
        term_end: second_month.end_of_month,
        credit_hours: 0
      )

      get :show

      doc = Capybara.string(response.body)
      expect(response.body).to include(half_time_school_name)
      expect(response.body).to include(less_than_half_time_school_name)
      expect(response.body).to include(I18n.t("components.enrollment_term_table_component.status.half_time"))
      expect(response.body).to include(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
    end

    context "with self-attested employment activities" do
      it "includes self-attested employment in all_activities list" do
        employment_activity = create(:employment_activity, activity_flow: activity_flow)
        create(
          :employment_activity_month,
          employment_activity: employment_activity,
          month: activity_flow.reporting_months.first.beginning_of_month,
          hours: 40,
          gross_income: 500
        )

        get :show

        all_activities = assigns(:all_activities)
        income_activity = all_activities.find { |a| a[:type] == :employment && a[:employment_activity].present? }
        expect(income_activity).to be_present
        expect(income_activity[:employment_activity]).to eq(employment_activity)
      end

      it "renders self-attested employment details and monthly values in the summary table" do
        employment_activity = create(
          :employment_activity,
          activity_flow: activity_flow,
          employer_name: "Gainesville Wrecking",
          street_address: "942 W Harlan Ave",
          city: "Gainesville",
          state: "FL",
          zip_code: "32601",
          contact_name: "Donny Spears",
          contact_email: "donny@gainesvillewrecking.com",
          contact_phone_number: "(415) 344-8009"
        )
        activity_month = create(
          :employment_activity_month,
          employment_activity: employment_activity,
          month: activity_flow.reporting_months.first.beginning_of_month,
          hours: 40,
          gross_income: 500
        )

        get :show

        expect(response.body).to include(employment_activity.employer_name)
        expect(response.body).to include(employment_activity.formatted_address)
        expect(response.body).to include(employment_activity.contact_name)
        expect(response.body).to include(employment_activity.contact_email)
        expect(response.body).to include(employment_activity.contact_phone_number)
        expect(response.body).to include(I18n.l(activity_month.month, format: :month))
        expect(response.body).to include(ActionController::Base.helpers.number_to_currency(activity_month.gross_income))
        expect(response.body).to include(activity_month.hours.to_s)
      end
    end

    context "with payroll accounts" do
      it "includes synced payroll accounts in all_activities list" do
        payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow)
        activity_flow.reporting_months.each do |month|
          create(:activity_flow_monthly_summary, activity_flow: activity_flow, payroll_account: payroll_account, month: month.beginning_of_month)
        end

        get :show

        all_activities = assigns(:all_activities)
        income_activity = all_activities.find { |a| a[:type] == :employment }
        expect(income_activity).to be_present
        expect(income_activity[:payroll_account]).to eq(payroll_account)
      end

      it "excludes unsynced payroll accounts from all_activities list" do
        create(:payroll_account, flow: activity_flow, synchronization_status: :in_progress)

        get :show

        all_activities = assigns(:all_activities)
        income_activity = all_activities.find { |a| a[:type] == :employment }
        expect(income_activity).to be_nil
      end

      it "renders persisted income summaries in the response" do
        payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "acct-123")
        latest_month = activity_flow.reporting_months.max
        activity_flow.reporting_months.each do |month|
          create(
            :activity_flow_monthly_summary,
            activity_flow: activity_flow,
            payroll_account: payroll_account,
            month: month.beginning_of_month,
            employer_name: "Acme Employer",
            employment_type: "w2",
            total_w2_hours: (month == latest_month ? 40.0 : 0.0),
            accrued_gross_earnings_cents: (month == latest_month ? 123_45 : 0),
            paychecks_count: (month == latest_month ? 2 : 0)
          )
        end

        get :show

        expect(response.body).to include("Acme Employer")
        expect(response.body).to include("$123.45")
      end

      it "renders successfully when no summaries are persisted" do
        create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "acct-123")
        allow(AggregatorReportFetcher).to receive(:new).with(activity_flow).and_return(double(report: nil))

        get :show

        expect(response).to have_http_status(:ok)
      end
    end

    it "renders both self-attested and synced payroll employment when both are present" do
      payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "acct-123")
      latest_month = activity_flow.reporting_months.max
      activity_flow.reporting_months.each do |month|
        create(
          :activity_flow_monthly_summary,
          activity_flow: activity_flow,
          payroll_account: payroll_account,
          month: month.beginning_of_month,
          employer_name: "Validated Employer",
          employment_type: "w2",
          total_w2_hours: (month == latest_month ? 35.0 : 0.0),
          accrued_gross_earnings_cents: (month == latest_month ? 222_22 : 0),
          paychecks_count: (month == latest_month ? 2 : 0)
        )
      end

      self_attested = create(
        :employment_activity,
        activity_flow: activity_flow,
        employer_name: "Self Attested Employer"
      )
      create(
        :employment_activity_month,
        employment_activity: self_attested,
        month: activity_flow.reporting_months.first.beginning_of_month,
        hours: 25,
        gross_income: 450
      )

      get :show

      expect(response.body).to include("Validated Employer")
      expect(response.body).to include("Self Attested Employer")

      employment_entries = assigns(:all_activities).select { |entry| entry[:type] == :employment }
      expect(employment_entries).to include(hash_including(payroll_account: payroll_account))
      expect(employment_entries).to include(hash_including(employment_activity: self_attested))
    end

    it "renders the legal agreement checkbox" do
      get :show

      expect(response.body).to include(I18n.t("activities.summary.legal_agreement"))
    end

    it "renders the submit button with agency name" do
      get :show

      expect(response.body).to include("Submit to")
    end

    it "renders a back link pointing to the activity hub" do
      get :show

      expect(response.body).to include("back-nav")
      expect(response.body).to have_link(href: activities_flow_root_path)
    end

    context "with previously uploaded documents across activity types" do
      before do
        Rails.application.config.active_storage.service = :local
      end

      it "renders each activity's uploaded documents, read-only, without edit links" do
        volunteering = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Food Bank", hours: 1)
        volunteering.document_uploads.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "volunteer-hours.pdf",
          content_type: "application/pdf"
        )

        job_training = create(:job_training_activity, activity_flow: activity_flow, program_name: "Workshop", hours: 6)
        job_training.document_uploads.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "training-cert.pdf",
          content_type: "application/pdf"
        )

        education = create(
          :education_activity,
          activity_flow: activity_flow,
          data_source: :fully_self_attested,
          school_name: "University"
        )
        create(:education_activity_month, education_activity: education, month: activity_flow.reporting_months.first, hours: 4)
        education.document_uploads.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "transcript.pdf",
          content_type: "application/pdf"
        )

        employment = create(:employment_activity, activity_flow: activity_flow)
        create(
          :employment_activity_month,
          employment_activity: employment,
          month: activity_flow.reporting_months.first.beginning_of_month,
          hours: 40,
          gross_income: 500
        )
        employment.document_uploads.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "paystub.pdf",
          content_type: "application/pdf"
        )

        get :show

        expect(response.body).to include("volunteer-hours.pdf")
        expect(response.body).to include("training-cert.pdf")
        expect(response.body).to include("transcript.pdf")
        expect(response.body).to include("paystub.pdf")
        expect(response.body).not_to include(I18n.t("activities.document_uploads.remove_file"))
        expect(response.body).not_to include(new_activities_flow_income_employment_document_upload_path(employment_id: employment))
        expect(response.body).not_to include(new_activities_flow_community_service_document_upload_path(community_service_id: volunteering))
        expect(response.body).not_to include(new_activities_flow_job_training_document_upload_path(job_training_id: job_training))
        expect(response.body).not_to include(new_activities_flow_education_document_upload_path(education_id: education))
      end
    end
  end

  describe "PATCH #update" do
    it "marks the flow as completed and redirects to success" do
      expect {
        patch :update, params: { activity_flow: { consent_to_submit: "1" } }
      }.to change { activity_flow.reload.completed_at }.from(nil)

      expect(response).to redirect_to(activities_flow_success_path)
    end

    it "re-renders summary with alert when consent is missing and keeps activity table content" do
      create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Helping Hands"
      )

      patch :update

      expect(activity_flow.reload.completed_at).to be_nil
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to eq(I18n.t("activities.submit.consent_required"))
      expect(response.body).to include("Helping Hands")
      expect(response.body).to include(I18n.t("activities.summary.legal_agreement"))
    end

    it "generates a confirmation code" do
      expect(activity_flow.confirmation_code).to be_nil

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to be_present
      expect(activity_flow.confirmation_code).to start_with(activity_flow.cbv_applicant.client_agency_id.upcase)
    end

    it "formats the agency name in the confirmation code" do
      activity_flow.cbv_applicant.update!(client_agency_id: "la_ldh")
      expect(activity_flow.confirmation_code).to be_nil

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to start_with(activity_flow.cbv_applicant.client_agency_id.gsub("_", "").upcase)
    end

    it "does not overwrite an existing confirmation code" do
      activity_flow.update(confirmation_code: test_confirmation_code)

      patch :update, params: { activity_flow: { consent_to_submit: "1" } }

      expect(activity_flow.reload.confirmation_code).to eq(test_confirmation_code)
    end
  end
end
