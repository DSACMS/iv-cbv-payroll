class CbvApplicant::PaDhs < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    case_number
  ]

  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string
    # Note: income_changes is handled separately in redact! method
  )

  validates :case_number, presence: true

  def redact!(fields = nil)
    self[:income_changes] = redact_member_names_in_json(self[:income_changes])
    super(fields)
  end

  def agency_expected_names
    return [] if redacted_at?

    Array(income_changes).map { |c| c["member_name"] }.uniq
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
