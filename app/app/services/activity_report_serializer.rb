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
      "agency" => agency,
      "ce_report" => {
        "review_period" => review_period,
        "individual" => individual,
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

  def agency
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

  def individual
    {
      "name" => {
        "first" => applicant.first_name,
        "middle" => applicant.middle_name,
        "last" => applicant.last_name
      },
      "extended_attributes" => {}
    }
  end

  def documents
    identified_documents.map do |document, document_id|
      {
        "document_id" => document_id,
        "document_name" => document.file_name,
        "file_type" => File.extname(document.file_name).delete_prefix(".")
      }
    end
  end

  def identified_documents
    @identified_documents ||= ActivityDocumentsService.new(@activity_flow)
      .all
      .select { |document| in_scope_associations.include?(document.activity.class.flow_association) }
      .each_with_index
      .map { |document, index| [ document, format("DOC-%03d", index + 1) ] }
  end

  def in_scope_associations
    @in_scope_associations ||= SELF_ATTESTED_ACTIVITY_TYPES.values.map { |config| config[:association] }
  end

  def document_ids_by_activity
    @document_ids_by_activity ||= identified_documents
      .group_by { |document, _| document.activity }
      .transform_values { |pairs| pairs.map(&:last) }
  end

  def document_ids_for(activity)
    document_ids_by_activity.fetch(activity, [])
  end

  def activities
    SELF_ATTESTED_ACTIVITY_TYPES.each_with_object({}) do |(type, config), result|
      result[type] = months_for(type, config)
    end
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
end
