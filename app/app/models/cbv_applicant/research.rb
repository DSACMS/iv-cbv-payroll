class CbvApplicant::Research < CbvApplicant
  VALID_ATTRIBUTES = %i[
    case_number
    date_of_birth
  ]

  has_redactable_fields(
    date_of_birth: :date
  )
end
