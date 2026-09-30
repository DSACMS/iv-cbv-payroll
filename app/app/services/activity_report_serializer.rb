class ActivityReportSerializer
  SCHEMA_VERSION = "1.0.0"

  SELF_ATTESTED_ACTIVITY_TYPES = {
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
      fields: EmploymentActivity::FIELDS + %w[additional_comments]
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
        "activities" => activities,
        "extended_attributes" => {}
      }
    }
  end

  private

  def applicant
    @activity_flow.cbv_applicant
  end

  def agency_partner_metadata
    metadata = CbvApplicant.build_agency_partner_metadata(@current_agency.id) do |attribute|
      json_value(applicant.public_send(attribute))
    end

    metadata.merge("extended_attributes" => {})
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
    SELF_ATTESTED_ACTIVITY_TYPES.each_with_object({}) do |(type, config), result|
      result[type] = months_for(type, config)
      if type == "employment"
        payroll_months.each do |month, entries|
          result[type][month] = result[type].fetch(month, []) + entries
        end
        result[type] = result[type].sort.to_h
      end
    end
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
            "extended_attributes" => {},
            "paystubs" => monthly_paystubs.map { |paystub| payroll_paystub(paystub) }
          )
        end
      end
    end

    entries_by_month
  end

  def payroll_paystub(paystub)
    paystub.merge(
      "extended_attributes" => {},
      "deductions" => paystub.fetch("deductions").map { |deduction| deduction.merge("extended_attributes" => {}) },
      "gross_pay_list" => paystub.fetch("gross_pay_list").map { |earning| earning.merge("extended_attributes" => {}) }
    )
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
    if type == "employment"
      attributes.merge!(
        "employer_address" => activity.formatted_address.presence,
        "employment_type" => activity.unpaid_or_in_kind? ? "unpaid" : (activity.is_self_employed ? "self_employed" : "w2"),
        "gross_income" => activity_month.gross_income.to_f
      )
    end

    { "type" => type }
      .merge(attributes)
      .merge(
        "month" => activity_month.month.strftime("%Y-%m"),
        "hours" => activity_month.hours.to_f,
        "data_source" => "self_attested",
        "document_ids" => document_ids_for(activity),
        "extended_attributes" => {}
      )
  end

  def json_value(value)
    return value.iso8601 if value.respond_to?(:iso8601)
    return value.presence if value.is_a?(String)

    value
  end

  class PayrollReportError < StandardError; end
end
