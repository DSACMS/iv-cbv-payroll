EMPLOYMENT_FIELDS = %i[
  account_id
  employer_name
  start_date
  termination_date
  status
  employer_phone_number
  employer_address
]

module ResponseObjects
  Employment = Struct.new(*EMPLOYMENT_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        employer_name: response_body["employer_name"],
        start_date: response_body["start_date"],
        termination_date: response_body["termination_date"],
        status: response_body["status"],
        employer_phone_number: OpenStruct.new(
          value: response_body["employer_phone_number"]["value"],
          type: response_body["employer_phone_number"]["type"],
        ),
        employer_address: OpenStruct.new(
          raw: response_body["employer_address"]["raw"],
        ),
      )
    end
  end
end
