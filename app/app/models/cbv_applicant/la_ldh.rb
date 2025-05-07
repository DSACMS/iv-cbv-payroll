class CbvApplicant::LaLdh < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    case_number
    date_of_birth
  ]
end
