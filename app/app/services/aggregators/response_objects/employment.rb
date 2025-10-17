module Aggregators::ResponseObjects
  EMPLOYMENT_FIELDS = %i[
    account_id
    employer_name
    start_date
    termination_date
    status
    employer_phone_number
    employer_address
    employment_type
    account_source
    employer_id
    employment_matching_id
  ]

  Employment = Struct.new(*EMPLOYMENT_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body, platform_body = nil)
      new(
        account_id: response_body["account_id"],
        employer_name: response_body["employer_name"],
        start_date: response_body["start_date"],
        termination_date: response_body["termination_date"],
        status: response_body["status"],
        employer_phone_number: response_body.dig("employer_phone_number", "value"),
        employer_address: response_body.dig("employer_address", "raw"),
        employment_type: Aggregators::FormatMethods::Pinwheel.employment_type(response_body["employer_name"]),
        account_source: platform_body&.dig("name"),
        employer_id: response_body["id"],
        employment_matching_id: response_body["id"]
      )
    end

    def self.from_argyle(identity_response_body, a_paystub_response_body = nil, account_json = nil)
      new(
        account_id: identity_response_body["account"],
        employer_name: identity_response_body["employer"],
        start_date: identity_response_body["hire_date"],
        termination_date: identity_response_body["termination_date"],
        status: Aggregators::FormatMethods::Argyle.format_employment_status(identity_response_body["employment_status"]),
        employer_address: Aggregators::FormatMethods::Argyle.format_employer_address(a_paystub_response_body),
        employment_type: Aggregators::FormatMethods::Argyle.employment_type(identity_response_body["employment_type"]),
        account_source: account_json&.dig("source"),
        employer_id: account_json&.dig("item"),
        employment_matching_id: identity_response_body["employment"]
      )
    end
  end
end
