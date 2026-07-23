class CbvApplicant::Hawaii < CbvApplicant
  VALID_ATTRIBUTES = %i[
    case_number
  ]

  has_redactable_fields(
    case_number: :string
  )
end
