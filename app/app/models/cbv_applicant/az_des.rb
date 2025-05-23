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
    # TODO[FFS-2669]: Redact income_changes by removing member name only.
  )

  validates :case_number, presence: true
end
