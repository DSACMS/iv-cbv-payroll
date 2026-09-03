class CbvApplicant::LaLdh < CbvApplicant
  validates :case_number,
            length: { maximum: 13 },
            allow_blank: true

  validate :require_doc_or_individual_id

  def require_doc_or_individual_id
    return if doc_id.present? || individual_id.present?

    errors.add(:base, I18n.t("cbv.applicant_informations.la_ldh.fields.doc_id_or_individual_id.blank"))
  end
end
