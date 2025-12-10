namespace :activity_flow_invitation do
  desc "create tokenized link for Activity Hub, ex: rake activity_flow_invitation:create[my_reference_id]"
  task :create, [ :reference_id ] => :environment do |_, args|
    raise "❌ Can't run this in prod! ❌" if Rails.env.production?

    log = ActiveSupport::Logger.new($stdout)
    begin
      invitation = ActivityFlowInvitation.create!(
        client_agency_id: "sandbox",
        reference_id: args[:reference_id]
      )

      log.info invitation.to_url
      log.info "Activity flow invitation created successfully! 🎉"
    rescue => e
      log.error "Failed to create activity flow invitation ☹️ : #{e}"
    end
  end
end
