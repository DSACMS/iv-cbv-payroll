require "rails_helper"

RSpec.describe Activities::ExpiredInvitationsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:document) { Capybara.string(response.body) }
  let(:agency) { Rails.application.config.client_agencies["la_ldh"] }

  describe "GET #show" do
    before { get :show, params: { client_agency_id: "la_ldh" } }

    it "renders the design copy with agency-specific instructions" do
      expect(response).to have_http_status(:ok)
      expect(document).to have_selector("h1", text: "Your verification link is no longer valid")
      expect(document).to have_text("This can happen if you've already submitted information via LDH's self-service portal or if the time to submit has expired. Please reach out to LDH for assistance.")
    end

    it "opens the agency website in a new tab with secure link attributes" do
      expect(document).to have_link("Visit LDH website", href: agency.agency_contact_website, target: "_blank")
      expect(document.find_link("Visit LDH website")[:rel].split).to contain_exactly("noopener", "noreferrer")
    end

    it "uses the Emmy layout" do
      expect(document).to have_selector("title", text: "Your verification link is no longer valid | Emmy | Eligibility Made Easy", visible: :all)
    end
  end

  context "with an existing session from another agency" do
    before do
      session[:flow_id] = create(:activity_flow).id
      session[:flow_type] = :activity
      get :show, params: { client_agency_id: "la_ldh" }
    end

    it "uses the link's agency and does not show a session timeout modal" do
      expect(document).to have_link("Visit LDH website", href: agency.agency_contact_website)
      expect(document).to have_no_selector("#session-timeout-modal", visible: :all)
    end
  end

  context "without an agency" do
    before { get :show }

    it "renders generic instructions without an empty website link" do
      expect(response).to have_http_status(:ok)
      expect(document).to have_text("Please reach out to your benefits agency for assistance.")
      expect(document).to have_no_link("Visit your benefits agency website")
    end
  end

  context "with an agency domain" do
    before do
      request.host = agency.agency_domain
      get :show
    end

    it "uses the domain's agency" do
      expect(document).to have_link("Visit LDH website", href: agency.agency_contact_website)
    end
  end
end
