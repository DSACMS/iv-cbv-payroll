namespace :activity_flow do
  desc "create tokenized link for Activity Hub, ex: rake activity_flow:create[my_reference_id]"
  task :create, [ :reference_id ] => :environment do |_, args|
    raise "❌ Can't run this in prod! ❌" if Rails.env.production?

    log = ActiveSupport::Logger.new($stdout)
    begin
      flow = ActivityFlow.create_with_token(reference_id: args[:reference_id])
      link = Rails.application.routes.url_helpers.activities_flow_start_url(
        token: flow.token,
        host: "localhost:3000"
      )
      log.info link
      log.info "Activity flow link created successfully! 🎉"
    rescue => e
      log.error "Failed to create activity flow link ☹️ : #{e}"
    end
  end
end
