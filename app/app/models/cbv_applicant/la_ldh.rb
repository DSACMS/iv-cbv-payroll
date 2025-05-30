class CbvApplicant::LaLdh < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    case_number
    date_of_birth
  ]

  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    date_of_birth: :date
  )
end
