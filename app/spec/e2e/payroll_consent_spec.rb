require "rails_helper"

RSpec.describe "CE payroll consent", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:consent_heading) { I18n.t("activities.income.employer_searches.payroll_consent.heading") }
  let(:continue_label) { I18n.t("activities.income.employer_searches.payroll_consent.continue") }
  let(:close_label) { I18n.t("activities.income.employer_searches.payroll_consent.close") }
  let(:employers) do
    [
      Aggregators::ResponseObjects::SearchResult.from_argyle({ "id" => "first", "name" => "Example Employer", "kind" => "employer" }),
      Aggregators::ResponseObjects::SearchResult.from_pinwheel({ "id" => "second", "name" => "Other Employer", "response_type" => "employer" })
    ]
  end

  before do
    allow_any_instance_of(ProviderSearchService).to receive(:search).and_return(employers)
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    visit_search
  end

  def visit_search
    visit activities_flow_income_employer_search_path(query: "Example")
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.search_results_header"))
    # Replace only the external-provider handoff; consent requests use Rails.
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-controller="cbv-employer-search"]');
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "cbv-employer-search");
      window.openedProviders = [];
      controller.openProvider = async (selection) => {
        window.openedProviders.push(selection.id);
        controller.onExit();
      };
    JS
  end

  context "with the consent dialog open" do
    before do
      find("button[aria-label='Select Example Employer']").click
    end

    it "uses an H1 and provides appropriately sized icons and close target" do
      expect(page).to have_selector("dialog[open] h1", text: consent_heading)
      close_button = find("button[aria-label='#{close_label}']")
      expect(close_button.rect.width).to be >= 40
      expect(close_button.rect.height).to be >= 40
      expect(close_button.find("svg").rect.width).to eq(24)
      expect(close_button.find("svg").rect.height).to eq(24)
      expect(find(".payroll-consent__icon svg").rect.width).to eq(24)
      expect(find(".payroll-consent__icon svg").rect.height).to eq(24)
      expect(find(".payroll-consent__icon").rect.width).to eq(48)
      expect(find(".payroll-consent__icon").rect.height).to eq(48)
    end
  end

  it "can close or escape without consenting, and returns focus to the selection" do
    find("button[aria-label='Select Example Employer']").click
    expect(page).to have_selector("dialog[open]", text: consent_heading)
    expect(page).to have_no_text(I18n.t("activities.income.employer_searches.payroll_consent.error"))
    expect(page).to be_axe_clean
    find("button[aria-label='#{close_label}']").click
    expect(page).to have_no_selector("dialog[open]")
    expect(page).to have_selector("button[data-id='first']:focus")
    expect(flow.reload.payroll_consented_at).to be_nil
    find("button[aria-label='Select Example Employer']").click
    expect(page).to have_selector("dialog[open]", text: consent_heading)
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_no_selector("dialog[open]")
    expect(flow.reload.payroll_consented_at).to be_nil
    expect(page.evaluate_script("window.openedProviders")).to be_empty
  end

  it "navigates to success if the flow completes before selecting an employer" do
    flow.update!(completed_at: Time.current)
    find("button[aria-label='Select Example Employer']").click
    verify_page(page, title: I18n.t("activities.success.show.title", agency_name: I18n.t("shared.agency_full_name.sandbox")))
    expect(flow.reload.payroll_consented_at).to be_nil
  end

  it "navigates to success if the flow completes while the consent dialog is open" do
    find("button[aria-label='Select Example Employer']").click
    expect(page).to have_selector("dialog[open]", text: consent_heading)
    flow.update!(completed_at: Time.current)
    click_button continue_label
    verify_page(page, title: I18n.t("activities.success.show.title", agency_name: I18n.t("shared.agency_full_name.sandbox")))
    expect(flow.reload.payroll_consented_at).to be_nil
  end

  it "asks once across employers and page reloads" do
    find("button[aria-label='Select Example Employer']").click
    expect(page).to have_selector("dialog[open]", text: consent_heading)
    click_button continue_label
    expect(page).to have_no_selector("dialog[open]")
    expect(page).to have_selector("button[data-id='first']:not([disabled])")
    expect(page.evaluate_script("window.openedProviders")).to eq([ "first" ])
    expect(flow.reload.payroll_consented_at).to be_present

    find("button[aria-label='Select Other Employer']").click
    expect(page).to have_selector("button[data-id='second']:not([disabled])")
    expect(page.evaluate_script("window.openedProviders")).to eq([ "first", "second" ])
    expect(page).to have_no_selector("dialog[open]")

    visit_search
    find("button[aria-label='Select Example Employer']").click
    expect(page).to have_selector("button[data-id='first']:not([disabled])")
    expect(page.evaluate_script("window.openedProviders")).to eq([ "first" ])
    expect(page).to have_no_selector("dialog[open]")
  end
end
