IDENTITY_FIELDS = %i[
  account_id
  full_name
]

module ResponseObjects
  Identity = Struct.new(*IDENTITY_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        full_name: response_body["full_name"],
      )
    end
  end
end
