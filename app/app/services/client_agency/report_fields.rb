class ClientAgency::ReportFields
  extend ReportViewHelper

  def self.caseworker_fields_for(_cbv_flow)
    []
  end

  def self.applicant_fields_for(cbv_flow)
    [
      [ additional_jobs_to_report_string(cbv_flow), format_boolean(cbv_flow.has_other_jobs) ]
    ]
  end

  private

  def self.additional_jobs_to_report_string(cbv_flow)
    if cbv_flow.cbv_applicant.applicant_attributes.present?
      ".pdf.shared.additional_jobs_to_report_html" # render with <sup> tag
    else
      ".pdf.shared.additional_jobs_to_report"
    end
  end
end 