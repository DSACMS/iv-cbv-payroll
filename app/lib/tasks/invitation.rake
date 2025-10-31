namespace :invitation do
  desc "create invitation link to start flow, ex: rake invitation:create[la_ldh], (default: la_ldh)"
  task :create, [ :client_agency_id ] => :environment do |_, args|
    log = ActiveSupport::Logger.new($stdout)
    begin
      raise "❌ Can't run this in prod! ❌" if Rails.env.production?

      client_agency_id = args[:client_agency_id] || "la_ldh"
      user = User.find_or_create_by(
        email: "ffs-eng+#{client_agency_id}@navapbc.com",
        client_agency_id: client_agency_id
      )

      user.update(is_service_account: true)
      token = user.api_access_tokens.first || user.api_access_tokens.create
      invite = CbvFlowInvitation.new({
        user: user,
        client_agency_id: client_agency_id,
        language: "en",
        email_address: user.email,
        cbv_applicant_attributes: { first_name: "Joe", last_name: "Schmoe", client_agency_id: client_agency_id, case_number: rand(1000..9999).to_s }
      })
      invite.save!
      log.info "Invite link created successfully! 🎉"
      log.info invite.to_url(origin: nil).gsub("https", "http")
    rescue => e
      log.error "Failed to created invite link ☹️ : #{e}"
    end
  end
end
