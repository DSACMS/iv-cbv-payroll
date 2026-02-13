require_relative "smoke_helper"

RSpec.describe "Argyle gig worker flow", type: :feature do
  it "completes the Argyle gig worker flow through summary" do
    # -- Entry page --
    visit_site("sandbox", "/cbv/links/sandbox")
    complete_entry_page

    # -- Employer search: search for Uber --
    fill_in name: "query", with: "Uber"
    click_button "Search"

    expect(page).to have_content("Uber", wait: 15)
    find("div.usa-card__container", text: "Uber").click_button("Select")

    # -- Argyle modal (same sandbox credentials work for gig employers) --
    complete_argyle_modal

    # -- Synchronization: wait for real webhooks --
    wait_for_sync_completion

    # -- Payment details through summary --
    complete_post_sync_pages(employer_name: "Uber")
  end
end
