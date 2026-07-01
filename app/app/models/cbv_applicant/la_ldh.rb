class CbvApplicant::LaLdh < CbvApplicant
  validates :case_number,
            length: { maximum: 13 },
            allow_blank: true
end
