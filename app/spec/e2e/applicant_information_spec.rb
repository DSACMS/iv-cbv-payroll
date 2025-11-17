require "rails_helper"

RSpec.describe "Applicant information", type: :feature, js: true do
  include E2e::TestHelpers

  it "allows a user to review their information" do
    # /cbv/links/:client_agency_id
    visit cbv_flow_new_path(client_agency_id: "sandbox")

    # /cbv/applicant_information
    visit cbv_flow_applicant_information_path
    verify_page(page, title: I18n.t("cbv.applicant_informations.show.your_information"))
  end
end
