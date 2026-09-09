require "rails_helper"

RSpec.describe ActivityPdfReport do
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
      confirmation_code: "SANDBOX123"
    )
  end

  describe "#client_name" do
    it "uses the authoritative applicant name instead of the flow identity" do
      report = described_class.new(flow: activity_flow, caseworker: false)

      expect(report.client_name).to eq("Jordan Taylor")
    end

    it "does not display a synthetic identity when the applicant has no name" do
      cbv_applicant.update!(
        first_name: nil,
        middle_name: nil,
        last_name: nil
      )

      report = described_class.new(flow: activity_flow, caseworker: false)

      expect(report.client_name).to be_nil
    end
  end

  describe "#monthly_income_summaries_for" do
    it "returns one row for every month in a 12-month reporting window" do
      activity_flow.update!(reporting_window_months: 12)
      payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow)
      activity_flow.reporting_months.each_with_index do |month, index|
        create(
          :activity_flow_monthly_summary,
          activity_flow: activity_flow,
          payroll_account: payroll_account,
          month: month,
          accrued_gross_earnings_cents: index * 100,
          paychecks_count: index
        )
      end

      report = described_class.new(flow: activity_flow, caseworker: false)
      summaries = report.monthly_income_summaries_for(payroll_account)

      expect(summaries.map(&:first)).to eq(activity_flow.reporting_months.map(&:beginning_of_month))
      expect(summaries.last.second[:paychecks_count]).to eq(11)
    end
  end

  describe "#activity_month_records" do
    it "returns one row for every month in a 12-month reporting window" do
      activity_flow.update!(reporting_window_months: 12)
      activity = create(:volunteering_activity, activity_flow: activity_flow)
      reported_month = activity_flow.reporting_months.third
      activity_month = create(
        :volunteering_activity_month,
        volunteering_activity: activity,
        month: reported_month,
        hours: 18
      )

      report = described_class.new(flow: activity_flow, caseworker: false)
      records = report.activity_month_records(activity.volunteering_activity_months)

      expect(records.map(&:first)).to eq(activity_flow.reporting_months.map(&:beginning_of_month))
      expect(records.to_h.fetch(reported_month.beginning_of_month)).to eq(activity_month)
    end
  end

  describe "#education_entries" do
    it "creates a separate institution entry for each NSC school with its activity-level data" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded,
        school_name: nil,
        additional_comments: "Comment for the education activity"
      )
      education.document_uploads.attach(
        io: StringIO.new("synthetic document"),
        filename: "Transcript.pdf",
        content_type: "application/pdf"
      )
      reporting_window = activity_flow.reporting_window_range
      school_a_term = create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "School A",
        term_begin: reporting_window.begin,
        term_end: reporting_window.begin.end_of_month
      )
      school_b_term = create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "School B",
        term_begin: reporting_window.end.beginning_of_month,
        term_end: reporting_window.end
      )

      report = described_class.new(flow: activity_flow, caseworker: false)
      entries = report.education_entries

      expect(entries.map(&:school_name)).to eq([ "School A", "School B" ])
      expect(entries.map(&:enrollment_terms)).to eq([ [ school_a_term ], [ school_b_term ] ])
      expect(entries.map(&:comments)).to eq([
        "Comment for the education activity",
        "Comment for the education activity"
      ])
      expect(entries.map(&:documents)).to eq([ [ "Transcript.pdf" ], [ "Transcript.pdf" ] ])
    end

    it "preserves activity-level data when no enrollment terms overlap the reporting window" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded,
        additional_comments: "The transcript is for an earlier term"
      )
      education.document_uploads.attach(
        io: StringIO.new("synthetic document"),
        filename: "Transcript.pdf",
        content_type: "application/pdf"
      )
      create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "School A",
        term_begin: activity_flow.reporting_window_range.begin - 1.year,
        term_end: activity_flow.reporting_window_range.end - 1.year
      )

      report = described_class.new(flow: activity_flow, caseworker: false)
      entry = report.education_entries.sole

      expect(entry.school_name).to eq("School A")
      expect(entry.enrollment_terms).to be_empty
      expect(entry.comments).to eq("The transcript is for an earlier term")
      expect(entry.documents).to eq([ "Transcript.pdf" ])
      expect(report.included_activity_types).to include(:education)
    end
  end

  describe "#document_names_for" do
    it "uses original filenames in the client report and templated filenames in the caseworker report" do
      activity = create(:employment_activity, activity_flow: activity_flow)
      activity.document_uploads.attach(
        io: StringIO.new("synthetic document"),
        filename: "Pay Stub Final.PDF",
        content_type: "application/pdf"
      )

      client_report = described_class.new(flow: activity_flow, caseworker: false)
      caseworker_report = described_class.new(flow: activity_flow, caseworker: true)

      expect(client_report.document_names_for(activity)).to eq([ "Pay Stub Final.PDF" ])
      expect(caseworker_report.document_names_for(activity)).to eq([
        "SANDBOX123_employment_pay_stub_final_1.pdf"
      ])
    end
  end
end
