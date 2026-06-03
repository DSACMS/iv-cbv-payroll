# Operational tasks for sending caseworker fallback emails when primary transmission fails.
# See docs/superpowers/specs/2026-05-28-caseworker-mailer-fallback-design.md for usage.

namespace :caseworker_mailer_fallback do
  desc "List all failed CaseWorkerTransmitterJob executions with their fallback email and error"
  task preview: :environment do
    executions = SolidQueue::FailedExecution
      .joins(:job)
      .where(solid_queue_jobs: { class_name: "CaseWorkerTransmitterJob" })
      .includes(:job)

    if executions.empty?
      puts "No failed CaseWorkerTransmitterJob jobs found."
      next
    end

    puts "Found #{executions.count} failed CaseWorkerTransmitterJob job(s):\n\n"

    executions.each do |fe|
      begin
        cbv_flow_id = fe.job.arguments["arguments"][0]
        cbv_flow = CbvFlow.find_by(id: cbv_flow_id)

        if cbv_flow.nil?
          puts "  cbv_flow_id=#{cbv_flow_id}  [CbvFlow record not found]"
          puts
          next
        end

        agency = Rails.application.config.client_agencies[cbv_flow.cbv_applicant.client_agency_id]
        fallback_email = agency&.caseworker_fallback_email || "(no fallback email configured)"
        transmitted = cbv_flow.transmitted_at? ? "already sent at #{cbv_flow.transmitted_at}" : "not yet sent"

        puts "  cbv_flow_id=#{cbv_flow_id}  agency=#{agency&.id}  to=#{fallback_email}  case=#{cbv_flow.cbv_applicant.case_number}  transmitted=#{transmitted}"
        puts "  error: #{fe.message.to_s.truncate(300)}"
        puts
      rescue => e
        puts "  solid_queue_job_id=#{fe.job_id}  [Error reading job: #{e.message}]"
        puts
      end
    end
  end

  desc "Send caseworker fallback emails. Mode: schema_failures_only or all_failures"
  task :send, [ :mode ] => :environment do |_, args|
    mode = args[:mode]
    unless %w[schema_failures_only all_failures].include?(mode)
      abort "Usage:\n  bin/rails 'caseworker_mailer_fallback:send[schema_failures_only]'\n  bin/rails 'caseworker_mailer_fallback:send[all_failures]'"
    end

    result = CaseworkerMailerFallbackService.new.call(schema_only: mode == "schema_failures_only")

    result[:skipped].each { |reason| puts "  Skipped: #{reason}" }
    puts "\nSummary: #{result[:sent]} sent, #{result[:skipped].count} skipped"
  end
end
