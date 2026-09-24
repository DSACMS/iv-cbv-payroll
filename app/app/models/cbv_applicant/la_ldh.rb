class CbvApplicant::LaLdh < CbvApplicant
  validates :case_number,
            length: { maximum: 13 },
            allow_blank: true

  def self.api_v2_metadata_errors(flow_type, metadata)
    return [] unless flow_type.to_s == "income"
    return [] if metadata[:doc_id].present? || metadata[:individual_id].present?

    [
      {
        field: :doc_id_or_individual_id,
        message_key: "api.v2.la_ldh.fields.doc_id_or_individual_id.blank"
      }
    ]
  end
end
