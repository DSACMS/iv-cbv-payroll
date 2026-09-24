class CbvApplicant::LaLdh < CbvApplicant
  validates :case_number,
            length: { maximum: 13 },
            allow_blank: true

  def self.api_v2_metadata_errors(flow_type, metadata)
    return [] if metadata[:individual_id].present?

    [
      {
        field: :individual_id,
        message_key: "api.v2.la_ldh.fields.individual_id.blank"
      }
    ]
  end
end
