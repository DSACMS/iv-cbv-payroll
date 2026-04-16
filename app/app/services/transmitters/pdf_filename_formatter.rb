class Transmitters::PdfFilenameFormatter
  def self.format(cbv_flow, format_string)
    format_string % format_values(cbv_flow)
  rescue KeyError => e
    raise ArgumentError, "Invalid pdf filename format placeholder: #{e.key}"
  end

  def self.format_values(cbv_flow)
    {
      confirmation_code: cbv_flow.confirmation_code,
      consent_date: cbv_flow.consented_to_authorized_use_at.strftime("%Y%m%d"),
      consent_timestamp: cbv_flow.consented_to_authorized_use_at.strftime("%Y%m%d%H%M%S")
    }.merge(applicant_attribute_values(cbv_flow))
  end

  def self.applicant_attribute_values(cbv_flow)
    cbv_flow.cbv_applicant.applicant_attributes.each_with_object({}) do |attribute, values|
      values[attribute] = cbv_flow.cbv_applicant.public_send(attribute)
    end
  end
end
