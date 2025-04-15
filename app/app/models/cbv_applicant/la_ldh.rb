class CbvApplicant::LaLdh < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    case_number
  ]

  # Making case_number optional.
  # TODO: Confirm the case_number format.
  validates :case_number, presence: false
end
