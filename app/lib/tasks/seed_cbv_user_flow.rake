namespace :seed do
  desc "Seed the database with a CBV user flow for development"
  task :cbv_user_flow, [:locale] => :environment do |_, args|
    # Get the locale from args or default to English
    locale = args[:locale] || "en"
    
    # Validate locale
    unless ["en", "es"].include?(locale)
      puts "Error: Locale must be either 'en' (English) or 'es' (Spanish)"
      puts "Example: rake seed:cbv_user_flow[es]"
      next
    end

    # Create a user for the CBV flow
    user = User.find_or_create_by(email: "dev@example.com") do |u|
      u.client_agency_id = "sandbox"
      u.is_service_account = true
    end

    # Create an API access token for the user
    api_token = user.api_access_tokens.first_or_create!

    # Generate names for the applicant using Faker
    first_name = Faker::Name.first_name
    middle_name = Faker::Name.middle_name.presence || "M"
    last_name = Faker::Name.last_name
    
    cbv_applicant = CbvApplicant.create!(
      client_agency_id: "sandbox",
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      snap_application_date: Date.yesterday
    )

    # Create a CBV flow invitation
    cbv_flow_invitation = CbvFlowInvitation.create!(
      user: user,
      cbv_applicant: cbv_applicant,
      client_agency_id: "sandbox",
      email_address: "dev-test@example.com",
      language: locale
    )

    cbv_flow = CbvFlow.create!(
      cbv_flow_invitation: cbv_flow_invitation,
      cbv_applicant: cbv_applicant,
      client_agency_id: "sandbox",
      end_user_id: SecureRandom.uuid,
      additional_information: {}
    )

    # Get the base URL (localhost or ngrok if available)
    base_url = "http://localhost:3000"

    # Check if ngrok is running and get its URL
    # Only skip in test environment when not explicitly testing ngrok
    unless Rails.env.test? && !ENV["TEST_NGROK"]
      begin
        ngrok_response = Net::HTTP.get(URI("http://localhost:4040/api/tunnels"))
        ngrok_data = JSON.parse(ngrok_response)

        if ngrok_data["tunnels"].present?
          # Find the first https tunnel
          https_tunnel = ngrok_data["tunnels"].find { |tunnel| tunnel["proto"] == "https" }
          base_url = https_tunnel["public_url"] if https_tunnel
        end
      rescue => e
        # Ngrok is not running or not accessible, use localhost
        puts "Note: Ngrok not detected, using localhost URL. Start ngrok for a shareable URL."
      end
    end

    cbv_flow_url = Rails.application.routes.url_helpers.cbv_flow_entry_url(
      token: cbv_flow_invitation.auth_token,
      locale: locale,
      host: URI.parse(base_url).host,
      port: URI.parse(base_url).port,
      protocol: URI.parse(base_url).scheme
    )

    puts "Created CBV user flow with ID: #{cbv_flow.id}"
    puts "Access token: #{api_token.access_token}" if api_token.respond_to?(:access_token)
    puts "Invitation token: #{cbv_flow_invitation.auth_token}"
    puts "Language: #{locale}"

    if base_url.include?("ngrok")
      puts "Local URL: http://localhost:3000/#{locale}/cbv/entry?token=#{cbv_flow_invitation.auth_token}"
      puts "Shareable ngrok URL: #{cbv_flow_url}"
    else
      puts "CBV flow URL: #{cbv_flow_url}"
      puts "Note: Start ngrok to get a shareable URL."
    end

    puts "\nVisit this URL to start the CBV flow."
    puts "The flow will guide you through linking a payroll account."
  end

  desc "Delete a specific CBV user flow and all associated records"
  task :delete_cbv_user_flow, [:cbv_flow_id] => :environment do |_, args|
    if args[:cbv_flow_id].blank?
      puts "Error: Please provide a CBV flow ID. Example: rake seed:delete_cbv_user_flow[123]"
      next
    end

    cbv_flow_id = args[:cbv_flow_id]
    cbv_flow = CbvFlow.find_by(id: cbv_flow_id)

    if cbv_flow.nil?
      puts "Error: CBV flow with ID #{cbv_flow_id} not found."
      next
    end

    puts "Deleting CBV user flow with ID: #{cbv_flow_id} and all associated records..."

    # Count associated records before deletion
    invitation = cbv_flow.cbv_flow_invitation
    applicant = cbv_flow.cbv_applicant
    user = invitation&.user
    payroll_accounts_count = cbv_flow.payroll_accounts.count
    api_tokens_count = user&.api_access_tokens&.count || 0

    puts "The following records will be deleted:"
    puts "- 1 CbvFlow (ID: #{cbv_flow.id})"
    puts "- #{payroll_accounts_count} PayrollAccount(s) (via dependent: :destroy)"
    puts "- 1 CbvFlowInvitation (ID: #{invitation.id})" if invitation.present?
    puts "- 1 CbvApplicant (ID: #{applicant.id})" if applicant.present?
    puts "- #{api_tokens_count} ApiAccessToken(s)" if api_tokens_count > 0
    puts "- 1 User (ID: #{user.id})" if user.present?

    ActiveRecord::Base.transaction do
      # Delete the flow first (this will delete payroll accounts via dependent: :destroy)
      cbv_flow.destroy!
      
      # Delete the invitation
      invitation.destroy! if invitation.present?
      
      # Delete the applicant
      applicant.destroy! if applicant.present?
      
      # Delete the user and their API tokens
      if user.present?
        user.api_access_tokens.destroy_all
        user.destroy!
      end
      
      puts "Successfully deleted CBV user flow and all associated records."
    end
  end

  desc "Delete all CBV user flows and associated records"
  task delete_all_cbv_user_flows: :environment do
    puts "Deleting all CBV user flows and associated records..."
    
    # Count records before deletion
    cbv_flow_count = CbvFlow.count
    payroll_accounts_count = PayrollAccount.count
    
    # Get all invitations and applicants associated with flows
    invitation_ids = CbvFlowInvitation.joins(:cbv_flows).pluck(:id).uniq
    invitation_count = invitation_ids.count
    
    applicant_ids = CbvApplicant.joins(:cbv_flows).distinct.pluck(:id)
    applicant_count = applicant_ids.count
    
    # Get user IDs from invitations
    user_ids = CbvFlowInvitation.where(id: invitation_ids).pluck(:user_id).compact.uniq
    user_count = user_ids.count
    
    # Count API tokens
    api_token_count = ApiAccessToken.where(user_id: user_ids).count
    
    puts "The following records will be deleted:"
    puts "- #{cbv_flow_count} CbvFlow(s)"
    puts "- #{payroll_accounts_count} PayrollAccount(s) (via dependent: :destroy)"
    puts "- #{invitation_count} CbvFlowInvitation(s)"
    puts "- #{applicant_count} CbvApplicant(s)"
    puts "- #{api_token_count} ApiAccessToken(s)"
    puts "- #{user_count} User(s)"
    
    ActiveRecord::Base.transaction do
      # Delete flows first (this will delete payroll accounts via dependent: :destroy)
      CbvFlow.destroy_all
      
      # Delete invitations
      CbvFlowInvitation.where(id: invitation_ids).destroy_all
      
      # Delete applicants
      CbvApplicant.where(id: applicant_ids).destroy_all
      
      # Delete API tokens and users
      ApiAccessToken.where(user_id: user_ids).destroy_all
      User.where(id: user_ids).destroy_all
      
      puts "Successfully deleted #{cbv_flow_count} CBV user flows and all associated records."
    end
  end
end 