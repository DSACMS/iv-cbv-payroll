class ClientAgency::LaLdh::Configuration
  def self.doc_id(cbv_flow)
    cbv_flow.cbv_applicant.doc_id
  end
end
