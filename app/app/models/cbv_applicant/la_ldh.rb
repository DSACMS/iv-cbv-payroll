class CbvApplicant::LaLdh < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    case_number
    date_of_birth
    doc_id
  ]

  has_redactable_fields(
    date_of_birth: :date
  )
end
