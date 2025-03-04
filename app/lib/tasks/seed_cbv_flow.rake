namespace :seed do
  desc "Seed the database with a CBV flow for development"
  task :cbv_flow, [:locale] => :environment do |_, args|
    # Get the locale from args or default to English
    locale = args[:locale] || "en"
    
    # Validate locale
    unless ["en", "es"].include?(locale)
      puts "Error: Locale must be either 'en' (English) or 'es' (Spanish)"
      puts "Example: rake seed:cbv_flow[es]"
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

    puts "Created CBV flow with ID: #{cbv_flow.id}"
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

  desc "Delete a specific CBV flow and all associated records"
  task :delete_cbv_flow, [:cbv_flow_id] => :environment do |_, args|
    if args[:cbv_flow_id].blank?
      puts "Error: Please provide a CBV flow ID. Example: rake seed:delete_cbv_flow[123]"
      next
    end

    cbv_flow_id = args[:cbv_flow_id]
    cbv_flow = CbvFlow.find_by(id: cbv_flow_id)

    if cbv_flow.nil?
      puts "Error: CBV flow with ID #{cbv_flow_id} not found."
      next
    end

    puts "Deleting CBV flow with ID: #{cbv_flow_id}..."

    ActiveRecord::Base.transaction do
      cbv_flow.destroy!
      
      puts "Successfully deleted CBV flow and associated records."
      puts "Note: The invitation, user, and applicant were preserved."
    end
  end

  desc "Delete all CBV flows and associated records"
  task delete_all_cbv_flows: :environment do
    puts "Deleting all CBV flows and associated records..."
    
    ActiveRecord::Base.transaction do
      cbv_flow_count = CbvFlow.count
      CbvFlow.destroy_all
      
      puts "Successfully deleted #{cbv_flow_count} CBV flows and their associated records."
      puts "Note: Invitations, users, and applicants were preserved."
    end
  end
end 