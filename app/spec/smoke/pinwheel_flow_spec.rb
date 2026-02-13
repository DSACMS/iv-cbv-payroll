require_relative "smoke_helper"

RSpec.describe "Pinwheel flow", type: :feature do
  it "completes the Pinwheel flow for McKee Foods through summary" do
    # -- Entry page --
    visit_site("sandbox", "/cbv/links/sandbox")
    complete_entry_page

    # -- Employer search: search for McKee Foods (Pinwheel employer) --
    fill_in name: "query", with: "foo"
    click_button "Search"

    expect(page).to have_content("McKee Foods", wait: 15)
    find("div.usa-card__container", text: "McKee Foods").click_button("Select")

    # -- Pinwheel modal --
    complete_pinwheel_modal

    # -- Synchronization: wait for real webhooks --
    wait_for_sync_completion

    # -- Payment details through summary --
    complete_post_sync_pages(employer_name: "McKee Foods")
  end
end
