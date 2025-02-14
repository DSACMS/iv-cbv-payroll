class CbvApplicant::Nyc < CbvApplicant
  # New York City: 11 digits followed by 1 uppercase letter
  NYC_CASE_NUMBER_REGEX = /\A\d{11}[A-Z]\z/

  # New York City: 2 uppercase letters, followed by 5 digits, followed by 1 uppercase letter
  NYC_CLIENT_ID_REGEX = /\A[A-Z]{2}\d{5}[A-Z]\z/

  before_validation :format_case_number

  validates :case_number, format: { with: NYC_CASE_NUMBER_REGEX, message: :invalid_format }
  validates :client_id_number, format: { with: NYC_CLIENT_ID_REGEX, message: :invalid_format }
  validates :snap_application_date, presence: true,
    inclusion: { in: (Date.current - 30.days)..Date.current, message: :nyc_invalid_date }

  def format_case_number
    return if case_number.blank?
    case_number.upcase!
    if case_number.length == 9
      self.case_number = "000#{case_number}"
    end
  end
end
