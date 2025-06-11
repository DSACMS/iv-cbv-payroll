class CbvApplicant::AzDes < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    case_number
    income_changes
  ]

  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    income_changes: :object
  )

  validates :case_number, presence: true

  def redact!
    fields_to_redact = self.class.fields_to_redact || self.class.superclass.fields_to_redact
    raise "No fields to redact in #{self.class} (or its superclass)" unless fields_to_redact.present?

    fields_to_redact.each do |field, type|
      if field == :income_changes
        # handle income_changes JSONB field specifically for AZ DES
        self[field] = redact_member_names_in_json(self[field])
      else
        self[field] = Redactable::REDACTION_REPLACEMENTS[type]
      end
    end

    self[Redactable::REDACTED_TIMESTAMP_COLUMN] = Time.now
    save(validate: false)
  end

  private

  def redact_member_names_in_json(json_array)
    return json_array unless json_array.is_a?(Array)

    json_array.map do |income_change|
      next income_change unless income_change.is_a?(Hash)

      income_change.with_indifferent_access.tap do |record|
        record["member_name"] = Redactable::REDACTION_REPLACEMENTS[:string] if record.key?("member_name")
      end
    end
  end
end
