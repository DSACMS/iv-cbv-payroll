require_relative "smoke_helper"

RSpec.describe "Argyle W-2 flow", type: :feature do
  it "completes the full Argyle W-2 flow through submission and PDF download" do
    # -- Entry page --
    visit_site("sandbox", "/cbv/links/sandbox")
    complete_entry_page

    # -- Employer search: select Paychex via popular tile --
    click_button "Paychex"

    # -- Argyle modal --
    complete_argyle_modal

    # -- Synchronization: wait for real webhooks --
    wait_for_sync_completion

    # -- Payment details through summary --
    complete_post_sync_pages(employer_name: "Paychex")

    # -- Summary -> Submit --
    click_on "Continue"

    # -- Submit page --
    smoke_verify_page(title: "Submit your income report", wait: 10)
    find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
    click_on "Share my report with CBV"

    # -- Success page --
    smoke_verify_page(title: "Your income report was successfully sent", wait: 30)

    # Verify confirmation code is displayed
    expect(page).to have_content(/[A-Z0-9]{6,}/)

    # -- PDF download verification --
    download_link = find("a", text: "Download my report")
    pdf_url = download_link[:href]

    response = fetch_pdf_with_session(pdf_url)

    expect(response.code.to_i).to eq(200)
    expect(response["Content-Type"]).to include("application/pdf")
    expect(response.body.bytes.first(4)).to eq("%PDF".bytes)

    # Save PDF for manual inspection (the bash wrapper will open it)
    pdf_path = File.join(Dir.tmpdir, "smoke_test_argyle_w2_report_#{Time.now.to_i}.pdf")
    File.write(pdf_path, response.body, mode: "wb")
    $stderr.puts "[SMOKE] PDF saved to: #{pdf_path}"
  end
end
