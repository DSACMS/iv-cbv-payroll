require "rails_helper"

RSpec.describe Activities::SubmitController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:identity) do
    create(
      :identity,
      activity_flows_count: 0,
      first_name: "Synthetic",
      last_name: "Identity"
    )
  end
  let(:cbv_applicant) do
    create(
      :cbv_applicant,
      first_name: "Jordan",
      middle_name: nil,
      last_name: "Taylor"
    )
  end
  let(:activity_flow) do
    create(
      :activity_flow,
      cbv_applicant: cbv_applicant,
      identity: identity,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      reporting_window_months: 2
    )
  end
  let(:frozen_time) { Time.zone.local(2025, 12, 1, 12, 0, 0) }
  let(:test_confirmation_code) { "SANDBOX123" }

  around do |example|
    Timecop.freeze(frozen_time) { example.run }
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "renders successfully" do
      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("activities.submit.title"))
    end

    it "renders the submitted activity summaries and details from the approved design" do
      activity_flow.update!(completed_at: frozen_time, confirmation_code: test_confirmation_code)
      employment = create(
        :employment_activity,
        activity_flow: activity_flow,
        employer_name: "Garden State Market",
        contact_phone_number: "2255550199",
        additional_comments: "My schedule changed in November"
      )
      create(:employment_activity_month, employment_activity: employment, month: activity_flow.reporting_months.first, hours: 12, gross_income: 240)
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "Bayou College"
      )
      create(:education_activity_month, education_activity: education, month: activity_flow.reporting_months.first, hours: 3)
      volunteering = create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Food Pantry",
        street_address: "456 Service Road",
        additional_comments: "Food pantry schedule attached",
        hours: 5
      )
      volunteering.document_uploads.attach(
        io: StringIO.new("synthetic document"),
        filename: "Volunteer Log.pdf",
        content_type: "application/pdf"
      )
      create(
        :job_training_activity,
        activity_flow: activity_flow,
        program_name: "Career Prep",
        organization_address: "123 Main St",
        hours: 8
      )

      get :show, format: :pdf

      expect(response).to have_http_status(:ok)
      expect(response.header["Content-Type"]).to include("pdf")
      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to include("Emmy Community Engagement | Test Agency")
      expect(pdf_text).to include("Client and report information: Jordan Taylor")
      expect(pdf_text).to include("Food Pantry")
      expect(pdf_text).to include("Career Prep")
      expect(pdf_text).to include("Garden State Market")
      expect(pdf_text).to include("(225) 555-0199")
      expect(pdf_text).to include("Bayou College")
      expect(pdf_text).to include("Volunteer Log.pdf")
      expect(pdf_text).to include(test_confirmation_code)
      expect(pdf_text).to include("December 1, 2025 12:00:00 UTC")
      expect(pdf_text).to include(
        "School contact name",
        "School contact email",
        "School contact phone number"
      )
      expect(pdf_text.scan("Organization contact name").size).to eq(2)
      expect(pdf_text.scan("Organization contact email").size).to eq(2)
      expect(pdf_text.scan("Organization contact phone number").size).to eq(2)
      expect(pdf_text.index("Food pantry schedule attached")).to be < pdf_text.index("456 Service Road")
    end

    context "with an uploaded employment document" do
      before do
        activity_flow.update!(confirmation_code: test_confirmation_code)
        employment = create(
          :employment_activity,
          activity_flow: activity_flow,
          employer_name: "Garden State Market"
        )
        employment.document_uploads.attach(
          io: StringIO.new("synthetic document"),
          filename: "Shift Log.pdf",
          content_type: "application/pdf"
        )
      end

      it "renders the caseworker PDF when requested in an internal environment" do
        allow(controller).to receive(:internal_environment?).and_return(true)

        get :show, format: :pdf, params: { is_caseworker: "true" }

        expect(extract_pdf_text(response)).to include(
          "#{test_confirmation_code}_employment_shift_log_1.pdf"
        )
      end

      it "renders the client PDF when explicitly requested in an internal environment" do
        allow(controller).to receive(:internal_environment?).and_return(true)

        get :show, format: :pdf, params: { is_caseworker: "false" }

        expect(extract_pdf_text(response)).to include("Shift Log.pdf")
      end

      it "renders the client PDF outside an internal environment" do
        allow(controller).to receive(:internal_environment?).and_return(false)

        get :show, format: :pdf, params: { is_caseworker: "true" }

        expect(extract_pdf_text(response)).to include("Shift Log.pdf")
      end
    end

    it "uses the remaining summary overflow page for details" do
      employment = create(:employment_activity, activity_flow: activity_flow, employer_name: "Garden State Market")
      activity_flow.reporting_months.each do |month|
        create(:employment_activity_month, employment_activity: employment, month: month, hours: 12, gross_income: 240)
      end

      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded,
        school_name: nil,
        additional_comments: "This schedule covers both institutions"
      )
      3.times do |index|
        education.document_uploads.attach(
          io: StringIO.new("synthetic document"),
          filename: "Enrollment record #{index + 1}.pdf",
          content_type: "application/pdf"
        )
      end
      activity_flow.reporting_months.each_with_index do |month, index|
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education,
          school_name: "School #{index + 1}",
          term_begin: month.beginning_of_month,
          term_end: month.end_of_month,
          credit_hours: 3
        )
      end

      get :show, format: :pdf

      pages = PDF::Reader.new(StringIO.new(response.body)).pages
      last_summary_page = pages.reverse.find { |page| page.text.include?("Enrollment record 3.pdf") }
      expect(last_summary_page&.text).to include(
        "Enrollment record 3.pdf",
        "Employment details"
      )
      education_details_text = pages.find { |page| page.text.include?("Education details") }&.text
      expect(education_details_text).to include(
        "Education details",
        "This schedule covers both institutions"
      )
      expect(education_details_text).not_to include("Institution information")
    end

    it "omits contact rows that do not apply to self-employed work" do
      create(
        :employment_activity,
        activity_flow: activity_flow,
        employer_name: "Taylor Services",
        is_self_employed: true,
        street_address: "123 Main Street"
      )

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to include("Taylor Services", "123 Main Street")
      expect(pdf_text).not_to include(
        I18n.t("activities.summary.employment.contact_name"),
        I18n.t("activities.summary.employment.contact_email"),
        I18n.t("activities.summary.employment.contact_phone")
      )
    end

    it "renders community service hours from monthly records in the PDF" do
      activity_flow.update!(completed_at: frozen_time, confirmation_code: test_confirmation_code)
      volunteering = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Food Pantry", hours: nil)
      create(:volunteering_activity_month, volunteering_activity: volunteering, month: activity_flow.reporting_window_range.begin, hours: 17)
      create(:volunteering_activity_month, volunteering_activity: volunteering, month: activity_flow.reporting_window_range.begin + 1.month, hours: 19)

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to match(/Food Pantry.*October 2025\s+17.*November 2025\s+19/)
    end

    it "renders activity-level education data for each NSC school" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded,
        school_name: nil,
        additional_comments: "Comment for both reported schools"
      )
      education.document_uploads.attach(
        io: StringIO.new("synthetic document"),
        filename: "Transcript.pdf",
        content_type: "application/pdf"
      )
      reporting_window = activity_flow.reporting_window_range
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education,
        school_name: "School A",
        term_begin: reporting_window.begin,
        term_end: reporting_window.begin.end_of_month,
        credit_hours: 3
      )
      create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "School B",
        term_begin: reporting_window.end.beginning_of_month,
        term_end: reporting_window.end
      )

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text.scan("Comment for both reported schools").size).to eq(2)
      expect(pdf_text.scan("Transcript.pdf").size).to eq(2)
    end

    it "renders the approved W-2 payment details" do
      payroll_account = create_persisted_payroll_account(employment_type: "w2")
      paystub = Aggregators::ResponseObjects::Paystub.new(
        account_id: payroll_account.aggregator_account_id,
        gross_pay_amount: 800_00,
        pay_date: "2025-11-15",
        hours: nil,
        deductions: [
          Aggregators::ResponseObjects::Deduction.new(
            category: "health_insurance",
            tax: "pre_tax",
            amount: 100_00
          )
        ]
      )
      outside_reporting_window = Aggregators::ResponseObjects::Paystub.new(
        account_id: payroll_account.aggregator_account_id,
        gross_pay_amount: 999_00,
        pay_date: "2024-01-15",
        hours: 40,
        deductions: []
      )
      stub_detailed_income_report(
        payroll_account,
        employment_type: :w2,
        paystubs: [ paystub, outside_reporting_window ]
      )

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to match(/Payment information \(1\)\s+Your details/)
      expect(pdf_text).to include("Pay date")
      expect(pdf_text).to include("Payment before taxes (gross)")
      expect(pdf_text).to match(/Number of hours worked\s+Not provided/)
      expect(pdf_text).to include("Hourly wage: Hours paid")
      expect(pdf_text).to include("Deduction: Health insurance (pre-tax)")
      expect(pdf_text).not_to include("January 15, 2024")
    end

    it "omits mileage expenses for gig work without mileage" do
      payroll_account = create_persisted_payroll_account(employment_type: "gig", total_mileage: 0)
      paystub = Aggregators::ResponseObjects::Paystub.new(
        account_id: payroll_account.aggregator_account_id,
        gross_pay_amount: 450_00,
        pay_date: "2025-11-15"
      )
      stub_detailed_income_report(payroll_account, employment_type: :gig, paystubs: [ paystub ])

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to include("Payments from Payroll Employer")
      expect(pdf_text).to include("These were the dates that the client was paid")
      expect(pdf_text).to include("11/15/2025 - $450.00")
      expect(pdf_text).not_to include("Mileage expenses")
    end

    it "omits activity sections the client did not submit" do
      activity_flow.update!(completed_at: frozen_time, confirmation_code: test_confirmation_code)
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Food Pantry", hours: 5)

      get :show, format: :pdf

      pdf_text = extract_pdf_text(response)
      expect(pdf_text).to include("Community service summary")
      expect(pdf_text).not_to include("Employment summary")
      expect(pdf_text).not_to include("Education summary")
      expect(pdf_text).not_to include("Work program summary")
    end
  end

  def create_persisted_payroll_account(employment_type:, total_mileage: 0)
    payroll_account = create(
      :payroll_account,
      :pinwheel_fully_synced,
      flow: activity_flow,
      aggregator_account_id: "account1"
    )
    create(
      :activity_flow_employment_summary,
      activity_flow: activity_flow,
      payroll_account: payroll_account,
      employer_name: "Payroll Employer",
      employment_type: employment_type,
      employment_status: "employed"
    )
    activity_flow.reporting_months.each do |month|
      create(
        :activity_flow_monthly_summary,
        activity_flow: activity_flow,
        payroll_account: payroll_account,
        month: month,
        accrued_gross_earnings_cents: 450_00,
        paychecks_count: 1,
        total_gig_hours: employment_type == "gig" ? 20 : 0,
        total_mileage: total_mileage,
        total_w2_hours: employment_type == "w2" ? 32 : 0
      )
    end
    payroll_account
  end

  def stub_detailed_income_report(payroll_account, employment_type:, paystubs:)
    employment = Aggregators::ResponseObjects::Employment.new(
      account_id: payroll_account.aggregator_account_id,
      employer_name: "Payroll Employer",
      employment_type: employment_type
    )
    income = Aggregators::ResponseObjects::Income.new(
      account_id: payroll_account.aggregator_account_id,
      pay_frequency: "weekly",
      compensation_amount: 25_00,
      compensation_unit: "hourly"
    )
    account_report = Aggregators::AggregatorReports::AggregatorReport::AccountReportStruct.new(
      nil,
      income,
      employment,
      paystubs,
      []
    )
    detailed_report = instance_double(
      Aggregators::AggregatorReports::AggregatorReport,
      has_fetched?: true,
      employments: [ employment ]
    )
    allow(detailed_report).to receive(:find_account_report)
      .with(payroll_account.aggregator_account_id)
      .and_return(account_report)
    allow(AggregatorReportFetcher).to receive(:new)
      .with(activity_flow)
      .and_return(instance_double(AggregatorReportFetcher, report: detailed_report))
  end
end
