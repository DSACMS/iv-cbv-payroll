class CbvApplicant::Ma < CbvApplicant
  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }
  validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }
  validates :snap_application_date,
    inclusion: { in: Date.current.prev_year..Date.current, message: :invalid_date },
    if: -> { snap_application_date.present? }
end
