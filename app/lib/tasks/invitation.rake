namespace :invitation do
  desc "create and copy invitation link for use locally for agency (default: az_des)"
  task :create, [ :client_agency_id ] => [ :environment ] do |_, args|
    log = ActiveSupport::Logger.new($stdout)
    client_agency_id = args[:client_agency_id] || "az_des"
    user = User.find_or_create_by(
      email: "ffs-eng+#{client_agency_id}@navapbc.com",
      client_agency_id: "az_des"
    )

    user.update(is_service_account: true)
    token = user.api_access_tokens.first || user.api_access_tokens.create
    output = `curl -s -H "Content-Type: application/json" -H "Authorization: Bearer #{token.access_token}" -d '{"language":"en","client_agency_id":"la_ldh","agency_partner_metadata": {"case_number": "34243"}}' http://localhost:3000/api/v1/invitations`
    if JSON.parse(output)["tokenized_url"].present?
      log.info "Invite link created successfully! 🎉"
      log.info JSON.parse(output)["tokenized_url"]
    else
      log.info "Failed to created invite link ☹️"
    end
  end
end
