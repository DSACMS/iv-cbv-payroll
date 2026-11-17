# frozen_string_literal: true

class ActivityPdfReport
  EMPTY_INCOME_SUMMARY = {
    accrued_gross_earnings: 0,
    paychecks_count: 0,
    total_gig_hours: 0,
    total_mileage: 0,
    total_w2_hours: 0
  }.freeze

  EmploymentEntry = Struct.new(:source, :record, keyword_init: true) do
    def payroll?
      source == :payroll
    end
  end

  EducationEntry = Struct.new(:activity, :school_name, :enrollment_terms, :comments, :documents, keyword_init: true)

  attr_reader :flow, :report_created_at

  def initialize(flow:, caseworker:, report_created_at: Time.current)
    @flow = flow
    @caseworker = caseworker
    @report_created_at = report_created_at
  end

  def caseworker?
    @caseworker
  end

  def agency_name
    I18n.t("shared.agency_full_name.#{flow.cbv_applicant.client_agency_id}")
  end

  def client_name
    applicant = flow.cbv_applicant
    [ applicant.first_name, applicant.middle_name, applicant.last_name ].compact_blank.join(" ").presence
  end

  def employment_entries
    @employment_entries ||= (
      payroll_accounts.map { |account| EmploymentEntry.new(source: :payroll, record: account) } +
      employment_activities.map { |activity| EmploymentEntry.new(source: :self_attested, record: activity) }
    ).sort_by { |entry| entry.record.created_at }
  end

  def education_entries
    @education_entries ||= education_activities.flat_map do |activity|
      documents = document_names_for(activity)

      if activity.fully_self_attested?
        EducationEntry.new(
          activity: activity,
          school_name: activity.school_name,
          enrollment_terms: [],
          comments: activity.additional_comments,
          documents: documents
        )
      else
        term_groups = grouped_enrollment_terms(activity)
        term_groups = [ [] ] if term_groups.empty?

        term_groups.map do |terms|
          EducationEntry.new(
            activity: activity,
            school_name: terms.first&.school_name || activity.review_description_school_names,
            enrollment_terms: terms,
            comments: activity.additional_comments,
            documents: documents
          )
        end
      end
    end
  end

  def community_service_activities
    @community_service_activities ||= flow.volunteering_activities.published.order(:created_at)
  end

  def work_program_activities
    @work_program_activities ||= flow.job_training_activities.published.order(:created_at)
  end

  def included_activity_types
    types = []
    types << :employment if employment_entries.any?
    types << :education if education_entries.any?
    types << :community_service if community_service_activities.any?
    types << :work_programs if work_program_activities.any?
    types
  end

  def employment_summary_for(payroll_account)
    employment_summaries.fetch(payroll_account.aggregator_account_id, {})
  end

  def monthly_income_summaries_for(payroll_account)
    summaries = monthly_income_summaries.fetch(payroll_account.aggregator_account_id, {})

    flow.reporting_months.map do |month|
      [ month.beginning_of_month, summaries.fetch(month.strftime("%Y-%m"), EMPTY_INCOME_SUMMARY) ]
    end
  end

  def payroll_details_for(payroll_account)
    @payroll_details ||= {}
    return @payroll_details[payroll_account.id] if @payroll_details.key?(payroll_account.id)

    report = detailed_income_report
    account_id = payroll_account.aggregator_account_id
    has_employment = report.has_fetched? && report.employments.any? do |employment|
      employment.account_id == account_id
    end
    details = report.find_account_report(account_id) if has_employment
    details.paystubs = details.paystubs.select { |paystub| paystub_in_reporting_window?(paystub) } if details
    @payroll_details[payroll_account.id] = details
  end

  def activity_month_records(records)
    records_by_month = records.index_by { |record| record.month.beginning_of_month }

    flow.reporting_months.map do |month|
      month = month.beginning_of_month
      [ month, records_by_month[month] ]
    end
  end

  def document_names_for(activity)
    activity.document_uploads_attachments.includes(:blob).order(:id).map do |attachment|
      if caseworker?
        caseworker_documents_by_attachment_id.fetch(attachment.id).file_name
      else
        attachment.filename.to_s
      end
    end
  end

  private

  def grouped_enrollment_terms(activity)
    terms = activity.nsc_enrollment_terms
      .select { |term| term.within_reporting_window?(flow.reporting_window_range) }
      .sort_by { |term| [ term.term_begin, term.term_end ] }

    terms.group_by { |term| term.school_name.to_s.strip.downcase }.values
  end

  def education_activities
    @education_activities ||= flow.education_activities.published.order(:created_at).reject do |activity|
      activity.validated? && activity.nsc_enrollment_terms.none?
    end
  end

  def paystub_in_reporting_window?(paystub)
    pay_date = paystub.pay_date
    return false unless pay_date

    flow.reporting_window_range.cover?(Date.parse(pay_date))
  end

  def detailed_income_report
    return @detailed_income_report if defined?(@detailed_income_report)

    @detailed_income_report = AggregatorReportFetcher.new(flow).report
  end

  def payroll_accounts
    @payroll_accounts ||= flow.payroll_accounts.published.where(synchronization_status: :succeeded)
  end

  def employment_activities
    @employment_activities ||= flow.employment_activities.published
  end

  def employment_summaries
    @employment_summaries ||= flow.employment_summaries_by_account_with_fallback
  end

  def monthly_income_summaries
    @monthly_income_summaries ||= flow.monthly_summaries_by_account_with_fallback
  end

  def caseworker_documents_by_attachment_id
    @caseworker_documents_by_attachment_id ||= ActivityDocumentsService.new(flow).all.index_by do |document|
      document.attachment.id
    end
  end
end
