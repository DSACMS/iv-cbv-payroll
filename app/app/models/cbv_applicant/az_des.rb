class CbvApplicant::AzDes < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    case_number
    income_changes
  ]

  validates :case_number, presence: true
end
