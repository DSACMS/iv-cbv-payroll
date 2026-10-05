class ActivityReportSerializer
  SCHEMA_VERSION = "1.0.0"

  ACTIVITY_TYPES = {
    "community_service" => {
      association: :volunteering_activities,
      fields: %w[
        organization_name
        street_address
        street_address_line_2
        city
        state
        zip_code
        coordinator_name
        coordinator_email
        coordinator_phone_number
        additional_comments
      ]
    },
    "work_program" => {
      association: :job_training_activities,
      fields: %w[
        organization_name
        program_name
        street_address
        street_address_line_2
        city
        state
        zip_code
        contact_name
        contact_email
        contact_phone_number
        additional_comments
      ]
    },
    "employment" => {
      association: :employment_activities,
      fields: EmploymentActivity::FIELDS + %w[additional_comments],
      # Method returning extra fields for each self-attested activity month.
      additional_fields_method: :employment_fields,
      # Method returning additional activities grouped by month.
      additional_months_method: :payroll_months
    }
  }.freeze

  def initialize(activity_flow, current_agency)
    @activity_flow = activity_flow
    @current_agency = current_agency
  end

  def as_json
    {
      "schema_version" => SCHEMA_VERSION,
      "confirmation_code" => @activity_flow.confirmation_code,
      "completed_at" => @activity_flow.completed_at&.utc&.iso8601,
      "agency_partner_metadata" => agency_partner_metadata,
      "ce_report" => {
        "review_period" => review_period,
        "documents" => documents,
        "activities" => activities
      }
    }
  end

  private

  def applicant
    @activity_flow.cbv_applicant
  end

  def agency_partner_metadata
    CbvApplicant.build_agency_partner_metadata(@current_agency.id) do |attribute|
      json_value(applicant.public_send(attribute))
    end
  end

  def review_period
    range = @activity_flow.reporting_window_range

    {
      "start_month" => range.begin.strftime("%Y-%m"),
      "end_month" => range.end.strftime("%Y-%m")
    }
  end

  def documents
    all_documents.map do |document, document_id|
      {
        "document_id" => document_id,
        "document_name" => document.file_name,
        "file_type" => File.extname(document.file_name).delete_prefix(".")
      }
    end
  end

  def all_documents
    @all_documents ||= ActivityDocumentsService.new(@activity_flow)
      .all
      .map { |document| [ document, document.document_id ] }
  end

  def document_ids_by_activity
    @document_ids_by_activity ||= all_documents
      .group_by { |document, _| document.activity }
      .transform_values { |pairs| pairs.map(&:last) }
  end

  def document_ids_for(activity)
    document_ids_by_activity.fetch(activity, [])
  end

  def activities
    result = ACTIVITY_TYPES.each_with_object({}) do |(type, config), result|
      result[type] = months_for(type, config)
      next unless config[:additional_months_method]

      result[type] = result[type].merge(send(config[:additional_months_method])) do |_month, entries, additional_entries|
        entries + additional_entries
      end.sort.to_h
    end
    result.merge("education" => education_months)
  end

  def payroll_months
    entries_by_month = Hash.new { |hash, key| hash[key] = [] }
    fetcher = AggregatorReportFetcher.new(@activity_flow)

    @activity_flow.payroll_accounts.published.order(:id).select(&:sync_succeeded?).each do |account|
      report = fetcher.report_for_payroll_account(account)
      unless report&.has_fetched?
        raise PayrollReportError, "Could not fetch employment report for payroll account #{account.id}"
      end

      report.income_report_employments.each do |employment|
        employment = employment.as_json
        paystubs = employment.fetch("paystubs").select do |paystub|
          pay_date = paystub["pay_date"]&.to_date
          pay_date && @activity_flow.reporting_window_range.cover?(pay_date)
        end

        paystubs.group_by { |paystub| paystub.fetch("pay_date").to_date.strftime("%Y-%m") }.each do |month, monthly_paystubs|
          entries_by_month[month] << employment.merge(
            "type" => "employment",
            "month" => month,
            "data_source" => "validated",
            "document_ids" => [],
            "paystubs" => monthly_paystubs
          )
        end
      end
    end

    entries_by_month
  end

  def months_for(type, config)
    entries_by_month = Hash.new { |hash, key| hash[key] = [] }

    @activity_flow.public_send(config[:association]).published.order(:id).each do |activity|
      activity.activity_months.sort_by(&:month).each do |activity_month|
        entries_by_month[activity_month.month.strftime("%Y-%m")] << entry(type, config, activity, activity_month)
      end
    end

    entries_by_month.sort.to_h
  end

  def entry(type, config, activity, activity_month)
    attributes = config[:fields].index_with { |field| json_value(activity.public_send(field)) }
    attributes.merge!(send(config[:additional_fields_method], activity, activity_month)) if config[:additional_fields_method]

    { "type" => type }
      .merge(attributes)
      .merge(
        "month" => activity_month.month.strftime("%Y-%m"),
        "hours" => activity_month.hours.to_f,
        "data_source" => "self_attested",
        "document_ids" => document_ids_for(activity)
      )
  end

  def employment_fields(activity, activity_month)
    {
      "employer_address" => activity.formatted_address.presence,
      "employment_type" => activity.unpaid_or_in_kind? ? "unpaid" : (activity.is_self_employed ? "self_employed" : "w2"),
      "gross_income" => activity_month.gross_income.to_f
    }
  end

  def education_months
    entries_by_month = Hash.new { |hash, key| hash[key] = [] }

    @activity_flow.education_activities.published.order(:id).each do |activity|
      if activity.fully_self_attested?
        activity.activity_months.sort_by(&:month).each do |activity_month|
          month = activity_month.month.strftime("%Y-%m")
          entries_by_month[month] << self_attested_education_entry(activity, month, activity_month.hours)
        end
      else
        education_term_entries(activity).each do |entry|
          entries_by_month[entry["month"]] << entry
        end
      end
    end

    entries_by_month.sort.to_h
  end

  def education_term_entries(activity)
    resolver = EducationReportingMonthResolver.new(
      terms: activity.nsc_enrollment_terms.order(:term_begin, :id),
      reporting_months: @activity_flow.reporting_months
    )

    resolver.reporting_month_enrollments.flat_map do |enrollment|
      month = enrollment.month.strftime("%Y-%m")
      terms = (enrollment.terms + [ enrollment.effective_term ]).compact.uniq
      terms.map { |term| education_term_entry(activity, month, term) }
    end
  end

  def education_entry(activity, month)
    {
      "type" => "education",
      "month" => month,
      "document_ids" => document_ids_for(activity),
      "additional_comments" => json_value(activity.additional_comments)
    }
  end

  def self_attested_education_entry(activity, month, credit_hours)
    attributes = EducationActivity::FIELDS.index_with { |field| json_value(activity.public_send(field)) }

    education_entry(activity, month).merge(attributes).merge(
      "hours" => credit_hours&.to_f,
      "data_source" => "self_attested"
    )
  end

  def education_term_entry(activity, month, term)
    base = if activity.partially_self_attested?
             self_attested_education_entry(activity, month, term.credit_hours).merge("data_source" => "verified_enrollment_only")
           else
             education_entry(activity, month).merge("data_source" => "verified")
           end

    base.merge(
      "school_name" => json_value(term.school_name),
      "enrollment_status" => term.enrollment_status,
      "credit_hours" => term.credit_hours&.to_f,
      "term" => {
        "start_month" => term.term_begin.strftime("%Y-%m"),
        "end_month" => term.term_end.strftime("%Y-%m")
      }
    )
  end

  def json_value(value)
    return value.iso8601 if value.respond_to?(:iso8601)
    return value.presence if value.is_a?(String)

    value
  end

  class PayrollReportError < StandardError; end
end
