module ConfirmationCodeGeneratable
  extend ActiveSupport::Concern

  private

  def generate_confirmation_code(flow)
    prefix = flow.cbv_applicant.client_agency_id
    [
      prefix.gsub("_", ""),
      (Time.now.to_i % 36 ** 3).to_s(36).tr("OISB", "0158").rjust(3, "0"),
      flow.id.to_s.rjust(4, "0")
    ].compact.join.upcase
  end
end
