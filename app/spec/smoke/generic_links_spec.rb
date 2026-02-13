require_relative "smoke_helper"

RSpec.describe "Generic link homepages", type: :feature do
  it "loads the sandbox generic link page" do
    visit_site("sandbox", "/cbv/links/sandbox")
    smoke_verify_page(title: "Let's verify your income")
    expect(page).to have_current_path(%r{/cbv/}, url: true)
  end

  it "loads the LA LDH generic link page" do
    visit_site("la", "/cbv/links/la_ldh")
    smoke_verify_page(title: "Let's verify your income")
    expect(page).to have_current_path(%r{/cbv/}, url: true)
  end

  it "loads the LA LDH /start page" do
    visit_site("la", "/start")
    smoke_verify_page(title: "Let's verify your income")
    expect(page).to have_current_path(%r{/cbv/}, url: true)
  end
end
