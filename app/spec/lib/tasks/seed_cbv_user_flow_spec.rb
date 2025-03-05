require "rails_helper"
require "rake"

RSpec.describe "seed:cbv_user_flow" do
  before do
    # Clear any previously loaded tasks
    Rake::Task.clear
    # Load the Rails application tasks
    Rails.application.load_tasks

    # Mock the URL helper to include token and locale
    allow(Rails.application.routes.url_helpers).to receive(:cbv_flow_entry_url) do |args|
      token = args[:token]
      locale = args[:locale] || "en"
      "http://example.com/#{locale}/cbv/entry?token=#{token}"
    end
    
    # Mock the ngrok API call
    stub_request(:get, "http://localhost:4040/api/tunnels")
      .to_return(status: 404, body: "", headers: {})
  end

  it "creates a user, API token, CBV applicant, and CBV flow with default English locale" do
    expect {
      Rake::Task["seed:cbv_user_flow"].invoke
    }.to change { User.count }.by(1)
      .and change { ApiAccessToken.count }.by(1)
      .and change { CbvApplicant.count }.by(1)
      .and change { CbvFlow.count }.by(1)

    # Verify the output includes the token in the URL with English locale
    Rake::Task["seed:cbv_user_flow"].reenable
    expect { Rake::Task["seed:cbv_user_flow"].invoke }.to output(/CBV flow URL: http:\/\/example.com\/en\/cbv\/entry\?token=/).to_stdout

    user = User.find_by(email: "dev@example.com")
    expect(user).to be_present
    expect(user.client_agency_id).to eq("sandbox")
    expect(user.is_service_account).to be true

    api_token = user.api_access_tokens.first
    expect(api_token).to be_present

    cbv_applicant = CbvApplicant.last
    expect(cbv_applicant.first_name).to be_present
    expect(cbv_applicant.middle_name).to be_present
    expect(cbv_applicant.last_name).to be_present
    expect(cbv_applicant.client_agency_id).to eq("sandbox")

    cbv_flow = CbvFlow.last
    expect(cbv_flow.cbv_applicant).to eq(cbv_applicant)
    expect(cbv_flow.client_agency_id).to eq("sandbox")
    expect(cbv_flow.end_user_id).to be_present # Just check that it's present, not a specific value
    
    # Verify the invitation has English locale
    invitation = cbv_flow.cbv_flow_invitation
    expect(invitation.language).to eq("en")
  end
  
  it "creates a CBV flow with Spanish locale when specified" do
    # Create a task with args hash to simulate command line args
    task = Rake::Task["seed:cbv_user_flow"]
    task.reenable # Allow the task to be run again
    
    expect {
      # Pass locale as an argument
      task.invoke("es")
    }.to change { CbvFlow.count }.by(1)
    
    # Verify the invitation has Spanish locale
    invitation = CbvFlowInvitation.last
    expect(invitation.language).to eq("es")
    
    # Verify the output includes the token in the URL with Spanish locale
    task.reenable
    expect { task.invoke("es") }.to output(/CBV flow URL: http:\/\/example.com\/es\/cbv\/entry\?token=/).to_stdout
  end
  
  it "validates the locale parameter" do
    # Create a task with args hash to simulate command line args
    task = Rake::Task["seed:cbv_user_flow"]
    task.reenable # Allow the task to be run again
    
    # Test with invalid locale
    expect {
      task.invoke("fr") # French is not supported
    }.to output(/Error: Locale must be either 'en' \(English\) or 'es' \(Spanish\)/).to_stdout
    
    # Verify no flow was created with the invalid locale
    expect(CbvFlow.where("created_at > ?", 1.second.ago).count).to eq(0)
  end
  
  it "doesn't create duplicate records when run multiple times" do
    # Run once to create initial records
    Rake::Task["seed:cbv_user_flow"].execute
    
    # Get counts after first run
    user_count = User.count
    token_count = ApiAccessToken.count
    
    # Run again
    expect {
      Rake::Task["seed:cbv_user_flow"].execute
    }.to change { User.count }.by(0)
      .and change { ApiAccessToken.count }.by(0)
      .and change { CbvApplicant.count }.by(1) # Still creates a new applicant
      .and change { CbvFlow.count }.by(1) # Still creates a new flow
      
    # Verify we still have the same user
    expect(User.count).to eq(user_count)
    expect(User.find_by(email: "dev@example.com")).to be_present
    
    # Verify we still have the same API token
    expect(ApiAccessToken.count).to eq(token_count)
  end
  
  context "when ngrok is running" do
    before do
      # Set environment variable to enable ngrok check in test
      ENV["TEST_NGROK"] = "true"
      
      # Mock a successful ngrok response
      ngrok_response = {
        "tunnels" => [
          {
            "name" => "command_line",
            "uri" => "/api/tunnels/command_line",
            "public_url" => "https://example-ngrok.io",
            "proto" => "https",
            "config" => {},
            "metrics" => {}
          }
        ]
      }
      
      stub_request(:get, "http://localhost:4040/api/tunnels")
        .to_return(status: 200, body: ngrok_response.to_json, headers: { "Content-Type" => "application/json" })
    end
    
    after do
      # Clean up environment variable
      ENV.delete("TEST_NGROK")
    end
    
    it "includes ngrok URL in the output" do
      # Allow the URL helper to return a URL with the ngrok domain
      allow(Rails.application.routes.url_helpers).to receive(:cbv_flow_entry_url) do |args|
        token = args[:token]
        locale = args[:locale] || "en"
        "https://example-ngrok.io/#{locale}/cbv/entry?token=#{token}"
      end
      
      # Run the task once to get a token
      Rake::Task["seed:cbv_user_flow"].reenable
      Rake::Task["seed:cbv_user_flow"].invoke
      
      # Run again to test the output
      Rake::Task["seed:cbv_user_flow"].reenable
      expect {
        Rake::Task["seed:cbv_user_flow"].invoke
      }.to output(/Shareable ngrok URL: https:\/\/example-ngrok.io\/en\/cbv\/entry\?token=/).to_stdout
    end
  end
end

RSpec.describe "seed:delete_cbv_user_flow" do
  before do
    # Clear any previously loaded tasks
    Rake::Task.clear
    # Load the Rails application tasks
    Rails.application.load_tasks
    
    # Mock the URL helper for the seed task
    allow(Rails.application.routes.url_helpers).to receive(:cbv_flow_entry_url) do |args|
      token = args[:token]
      locale = args[:locale] || "en"
      "http://example.com/#{locale}/cbv/entry?token=#{token}"
    end
    
    # Mock the ngrok API call
    stub_request(:get, "http://localhost:4040/api/tunnels")
      .to_return(status: 404, body: "", headers: {})
  end
  
  it "deletes a specific CBV flow and all associated records" do
    Rake::Task["seed:cbv_user_flow"].invoke
    
    # Get the created flow and associated records
    cbv_flow = CbvFlow.last
    invitation = cbv_flow.cbv_flow_invitation
    applicant = cbv_flow.cbv_applicant
    user = invitation.user
    
    # Create a payroll account if the model exists
    if defined?(PayrollAccount)
      PayrollAccount::Pinwheel.create!(
        cbv_flow: cbv_flow,
        pinwheel_account_id: SecureRandom.uuid,
        supported_jobs: %w[income]
      )
    end
    
    # Execute the task with the flow ID
    Rake::Task["seed:delete_cbv_user_flow"].reenable
    
    # Verify the output includes information about what will be deleted
    output = StringIO.new
    $stdout = output
    
    Rake::Task["seed:delete_cbv_user_flow"].invoke(cbv_flow.id)
    
    $stdout = STDOUT
    output_string = output.string
    
    # Check that the output contains the expected information
    expect(output_string).to include("Deleting CBV user flow with ID: #{cbv_flow.id}")
    expect(output_string).to include("The following records will be deleted:")
    expect(output_string).to include("- 1 CbvFlow (ID: #{cbv_flow.id})")
    
    if defined?(PayrollAccount)
      expect(output_string).to include("- 1 PayrollAccount(s) (via dependent: :destroy)")
    end
    
    expect(output_string).to include("- 1 CbvFlowInvitation (ID: #{invitation.id})")
    expect(output_string).to include("- 1 CbvApplicant (ID: #{applicant.id})")
    expect(output_string).to include("- 1 ApiAccessToken(s)")
    expect(output_string).to include("- 1 User (ID: #{user.id})")
    expect(output_string).to include("Successfully deleted CBV user flow and all associated records")
    
    # Verify the flow is deleted
    expect(CbvFlow.find_by(id: cbv_flow.id)).to be_nil
    
    # Verify payroll accounts are deleted if they exist
    if defined?(PayrollAccount)
      expect(PayrollAccount.where(cbv_flow_id: cbv_flow.id).count).to eq(0)
    end
    
    # Verify the invitation, user, and applicant are also deleted
    expect(CbvFlowInvitation.find_by(id: invitation.id)).to be_nil
    expect(User.find_by(id: user.id)).to be_nil
    expect(CbvApplicant.find_by(id: applicant.id)).to be_nil
  end
  
  it "handles missing flow ID gracefully" do
    expect {
      Rake::Task["seed:delete_cbv_user_flow"].invoke
    }.to output(/Error: Please provide a CBV flow ID/).to_stdout
  end
  
  it "handles non-existent flow ID gracefully" do
    expect {
      Rake::Task["seed:delete_cbv_user_flow"].invoke(999999)
    }.to output(/Error: CBV flow with ID 999999 not found/).to_stdout
  end
end

RSpec.describe "seed:delete_all_cbv_user_flows" do
  before do
    # Clear any previously loaded tasks
    Rake::Task.clear
    # Load the Rails application tasks
    Rails.application.load_tasks
    
    # Mock the URL helper for the seed task
    allow(Rails.application.routes.url_helpers).to receive(:cbv_flow_entry_url) do |args|
      token = args[:token]
      locale = args[:locale] || "en"
      "http://example.com/#{locale}/cbv/entry?token=#{token}"
    end
    
    # Mock the ngrok API call
    stub_request(:get, "http://localhost:4040/api/tunnels")
      .to_return(status: 404, body: "", headers: {})
  end
  
  it "deletes all CBV flows and associated records" do
    # Create multiple test flows using the seed task
    Rake::Task["seed:cbv_user_flow"].invoke
    Rake::Task["seed:cbv_user_flow"].reenable
    Rake::Task["seed:cbv_user_flow"].invoke("es")
    
    # Create payroll accounts if the model exists
    if defined?(PayrollAccount)
      CbvFlow.all.each do |flow|
        PayrollAccount::Pinwheel.create!(
          cbv_flow: flow,
          pinwheel_account_id: SecureRandom.uuid,
          supported_jobs: %w[income]
        )
      end
    end
    
    # Record initial counts
    initial_flow_count = CbvFlow.count
    initial_invitation_count = CbvFlowInvitation.count
    initial_applicant_count = CbvApplicant.count
    initial_user_count = User.count
    initial_payroll_account_count = defined?(PayrollAccount) ? PayrollAccount.count : 0
    initial_api_token_count = ApiAccessToken.count
    
    # Execute the task
    Rake::Task["seed:delete_all_cbv_user_flows"].reenable
    
    # Capture and verify the output
    output = StringIO.new
    $stdout = output
    
    Rake::Task["seed:delete_all_cbv_user_flows"].execute
    
    $stdout = STDOUT
    output_string = output.string
    
    # Check that the output contains the expected information
    expect(output_string).to include("Deleting all CBV user flows and associated records...")
    expect(output_string).to include("The following records will be deleted:")
    expect(output_string).to include("- #{initial_flow_count} CbvFlow(s)")
    expect(output_string).to include("- #{initial_payroll_account_count} PayrollAccount(s) (via dependent: :destroy)")
    expect(output_string).to include("- #{initial_invitation_count} CbvFlowInvitation(s)")
    expect(output_string).to include("- #{initial_applicant_count} CbvApplicant(s)")
    expect(output_string).to include("- #{initial_api_token_count} ApiAccessToken(s)")
    expect(output_string).to include("- #{initial_user_count} User(s)")
    expect(output_string).to include("Successfully deleted #{initial_flow_count} CBV user flows and all associated records")
    
    # Verify all flows are deleted
    expect(CbvFlow.count).to eq(0)
    
    # Verify payroll accounts are deleted if they exist
    if defined?(PayrollAccount)
      expect(PayrollAccount.count).to eq(0)
    end
    
    # Verify invitations, users and applicants are also deleted
    expect(CbvFlowInvitation.count).to eq(0)
    expect(User.where(email: "dev@example.com").count).to eq(0)
    expect(CbvApplicant.count).to eq(0)
  end
end 