namespace :activity_flow_invitation do
  desc "create tokenized link for Activity Hub, ex: rake activity_flow_invitation:create[sandbox,my_reference_id,2025-01]"
  task :create, [ :client_agency_id, :reference_id, :reporting_month ] => :environment do |_, args|
    raise "❌ Can't run this in prod! ❌" if Rails.env.production?

    log = ActiveSupport::Logger.new($stdout)
    client_agency_id = args[:client_agency_id] || "sandbox"

    unless Rails.application.config.client_agencies[client_agency_id]
      log.error "Unknown agency: #{client_agency_id}"
      log.error "Valid agencies: #{Rails.application.config.client_agencies.client_agency_ids.join(', ')}"
      next
    end

    reporting_month = args[:reporting_month] ? Date.parse("#{args[:reporting_month]}-01") : Date.current.beginning_of_month

    begin
      invitation = ActivityFlowInvitation.create!(
        client_agency_id: client_agency_id,
        reference_id: args[:reference_id],
        reporting_month: reporting_month
      )

      log.info invitation.to_url
      log.info "Activity flow invitation created for #{client_agency_id}, reporting month: #{reporting_month.strftime('%B %Y')}! 🎉"
    rescue => e
      log.error "Failed to create activity flow invitation ☹️ : #{e}"
    end
  end
end
