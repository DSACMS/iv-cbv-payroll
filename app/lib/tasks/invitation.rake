namespace :invitation do
  desc "create invitation link to start flow, ex: rake invitation:create[la_ldh], (default: la_ldh)"
  task :create, [ :client_agency_id ] => :environment do |_, args|
    begin
      log = ActiveSupport::Logger.new($stdout)
      client_agency_id = args[:client_agency_id] || "la_ldh"
      user = User.find_or_create_by(
        email: "ffs-eng+#{client_agency_id}@navapbc.com",
        client_agency_id: client_agency_id
      )

      user.update(is_service_account: true)
      token = user.api_access_tokens.first || user.api_access_tokens.create
      output = `curl -s -H "Content-Type: application/json" -H "Authorization: Bearer #{token.access_token}" -d '{"language":"en","client_agency_id":"#{client_agency_id}","agency_partner_metadata": {"case_number": "#{rand(1000..9999)}", "first_name": "Joe", "last_name": "Schmoe"}}' http://localhost:3000/api/v1/invitations`
      log.info "Invite link created successfully! 🎉"
      log.info JSON.parse(output)["tokenized_url"].gsub("https", "http")
    rescue => e
      log.info "Failed to created invite link ☹️ : #{e}"
    end
  end
end
