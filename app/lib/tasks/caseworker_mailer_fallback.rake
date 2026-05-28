# Operational tasks for sending caseworker fallback emails when primary transmission fails.
# See docs/superpowers/specs/2026-05-28-caseworker-mailer-fallback-design.md for usage.

CASEWORKER_MAILER_FALLBACK_SCHEMA_PATTERN = "API Specification validation failed".freeze

namespace :caseworker_mailer_fallback do
  desc "List all failed CaseWorkerTransmitterJob executions with their fallback email and error"
  task preview: :environment do
    executions = failed_caseworker_executions

    if executions.empty?
      puts "No failed CaseWorkerTransmitterJob jobs found."
      next
    end

    puts "Found #{executions.count} failed CaseWorkerTransmitterJob job(s):\n\n"

    executions.each do |fe|
      begin
        cbv_flow_id = cbv_flow_id_from(fe)
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

    deliver_fallback_emails(schema_only: mode == "schema_failures_only")
  end
end

def failed_caseworker_executions
  SolidQueue::FailedExecution
    .joins(:job)
    .where(solid_queue_jobs: { class_name: "CaseWorkerTransmitterJob" })
    .includes(:job)
end

def cbv_flow_id_from(failed_execution)
  failed_execution.job.arguments["arguments"][0]
end

def deliver_fallback_emails(schema_only:)
  executions = failed_caseworker_executions
  if schema_only
    executions = executions.where("solid_queue_failed_executions.error LIKE ?", "%#{CASEWORKER_MAILER_FALLBACK_SCHEMA_PATTERN}%")
  end

  sent = 0
  skipped = []

  executions.each do |fe|
    cbv_flow_id = cbv_flow_id_from(fe)

    begin
      cbv_flow = CbvFlow.find_by(id: cbv_flow_id)
      unless cbv_flow
        skipped << "cbv_flow_id=#{cbv_flow_id}: CbvFlow record not found"
        next
      end

      if cbv_flow.transmitted_at?
        skipped << "cbv_flow_id=#{cbv_flow_id}: already transmitted at #{cbv_flow.transmitted_at}"
        next
      end

      if cbv_flow.cbv_applicant.redacted_at?
        skipped << "cbv_flow_id=#{cbv_flow_id}: applicant is redacted"
        next
      end

      agency = Rails.application.config.client_agencies[cbv_flow.cbv_applicant.client_agency_id]
      unless agency&.caseworker_fallback_email
        skipped << "cbv_flow_id=#{cbv_flow_id}: no caseworker_fallback_email configured for agency #{agency&.id || 'unknown'}"
        next
      end

      aggregator_report = AggregatorReportFetcher.new(cbv_flow).report
      CaseworkerMailer.with(
        email_address: agency.caseworker_fallback_email,
        cbv_flow: cbv_flow,
        aggregator_report: aggregator_report
      ).summary_email.deliver_now

      Rails.logger.info "[CaseworkerMailerFallback] Sent fallback email cbv_flow_id=#{cbv_flow.id} agency=#{agency.id} to=#{agency.caseworker_fallback_email}"
      cbv_flow.touch(:transmitted_at)
      fe.destroy

      puts "Sent: cbv_flow_id=#{cbv_flow.id}  agency=#{agency.id}  to=#{agency.caseworker_fallback_email}"
      sent += 1
    rescue => e
      Rails.logger.error "[CaseworkerMailerFallback] Error for cbv_flow_id=#{cbv_flow_id}: #{e.message}"
      puts "Error for cbv_flow_id=#{cbv_flow_id}: #{e.message}"
    end
  end

  puts "\nSummary: #{sent} sent, #{skipped.count} skipped"
  skipped.each { |reason| puts "  Skipped: #{reason}" }
end
