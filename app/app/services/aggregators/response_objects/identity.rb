module Aggregators::ResponseObjects
  IDENTITY_FIELDS = %i[
    account_id
    full_name
    date_of_birth
    emails
    ssn
    phone_numbers
  ]

  Identity = Struct.new(*IDENTITY_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        full_name: response_body["full_name"],
        date_of_birth: response_body["date_of_birth"],
        emails: response_body["emails"],
        ssn: ("XXX-XX-#{response_body["last_four_ssn"]}" if response_body["last_four_ssn"].present?),
        phone_numbers: response_body["phone_numbers"]
      )
    end

    def self.from_argyle(identity_response_body)
      new(
        account_id: identity_response_body["account"],
        full_name: identity_response_body["full_name"],
        date_of_birth: identity_response_body["birth_date"],
        emails: [ identity_response_body["email"] ],
        ssn: (identity_response_body["ssn"]&.last(4) if identity_response_body["ssn"].present?),
        phone_numbers: [ identity_response_body["phone_number"] ]
      )
    end
  end
end
