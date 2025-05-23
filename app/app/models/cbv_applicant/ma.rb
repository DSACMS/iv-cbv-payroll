class CbvApplicant::Ma < CbvApplicant
  # Attributes usable in the invitation API and caseworker page.
  VALID_ATTRIBUTES = %i[
    first_name
    middle_name
    last_name
    agency_id_number
    beacon_id
    snap_application_date
  ]

  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }
  validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }
  validates :snap_application_date,
    inclusion: {
      in: -> { Date.current.prev_year..Date.current },
      message: :invalid_date
    },
    if: -> { snap_application_date.present? }

  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    agency_id_number: :string,
    beacon_id: :string
  )
end
