namespace :invitation do
  desc "create invitation link to start flow, ex: rake invitation:create[la_ldh], (default: la_ldh)"
  task :create, [ :client_agency_id ] => :environment do |_, args|
    log = ActiveSupport::Logger.new($stdout)
    begin
      link = InvitationGenerator.create_invite_link(args[:client_agency_id] || "la_ldh")
      log.info link
      log.info "Invite link created successfully! 🎉"
    rescue => e
      log.error "Failed to created invite link ☹️ : #{e}"
    end
  end
end
