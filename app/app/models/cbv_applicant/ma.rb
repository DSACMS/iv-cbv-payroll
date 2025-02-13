class CbvApplicant::Ma < CbvApplicant
  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }
  validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }
  validate :ma_snap_application_date_not_more_than_1_year_ago
  validate :ma_snap_application_date_not_in_future

  def ma_snap_application_date_not_in_future
    if snap_application_date.present? && snap_application_date > Date.current
      errors.add(:snap_application_date, :ma_invalid_date)
    end
  end

  def ma_snap_application_date_not_more_than_1_year_ago
    if snap_application_date.present? && snap_application_date < 1.year.ago.to_date
      errors.add(:snap_application_date, :ma_invalid_date)
    end
  end
end
