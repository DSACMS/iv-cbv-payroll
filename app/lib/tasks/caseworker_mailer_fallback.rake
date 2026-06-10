# Operational tasks for sending caseworker fallback emails when primary transmission fails.
# See docs/superpowers/specs/2026-05-28-caseworker-mailer-fallback-design.md for usage.

namespace :caseworker_mailer_fallback do
  def validate_caseworker_mailer_fallback_filter!(mode, task_name)
    return if mode.blank? || CaseworkerMailerFallbackService::FILTERS.key?(mode)

    abort <<~USAGE
      Usage:
      bin/rails 'caseworker_mailer_fallback:#{task_name}'
      bin/rails 'caseworker_mailer_fallback:#{task_name}[la_ldh_schema_error]'
    USAGE
  end

  desc "List all failed CaseWorkerTransmitterJob executions with their fallback email and error. Optional filter: la_ldh_schema_error"
  task :preview, [ :mode ] => :environment do |_, args|
    mode = args[:mode]
    validate_caseworker_mailer_fallback_filter!(mode, "preview")

    result = CaseworkerMailerFallbackService.new.preview(filter_name: mode)

    if result[:count].zero?
      puts "No failed CaseWorkerTransmitterJob jobs found."
      next
    end

    puts "Found #{result[:count]} failed CaseWorkerTransmitterJob job(s):\n\n"

    result[:entries].each do |entry|
      if entry[:status] == :error
        puts "  solid_queue_job_id=#{entry[:solid_queue_job_id]}  [#{entry[:reason]}]"
      elsif entry[:cbv_flow].nil?
        puts "  cbv_flow_id=#{entry[:cbv_flow_id]}  [#{entry[:reason]}]"
      else
        puts "  cbv_flow_id=#{entry[:cbv_flow_id]}  agency=#{entry[:agency_id]}  to=#{entry[:fallback_email]}  case=#{entry[:case_number]}  transmitted=#{entry[:transmitted]}"
        puts "  status: #{entry[:reason]}" if entry[:status] == :skipped
        puts "  warning: #{entry[:warning]}" if entry[:warning].present?
        puts "  error: #{entry[:error].to_s.truncate(300)}"
      end
      puts
    end
  end

  desc "Send caseworker fallback emails. Optional filter: la_ldh_schema_error"
  task :deliver_all, [ :mode ] => :environment do |_, args|
    mode = args[:mode]
    validate_caseworker_mailer_fallback_filter!(mode, "deliver_all")

    result = CaseworkerMailerFallbackService.new.deliver_all(filter_name: mode)

    result[:warnings].each { |warning| puts "  Warning: #{warning}" }
    result[:skipped].each { |reason| puts "  Skipped: #{reason}" }
    puts "\nSummary: #{result[:sent]} sent, #{result[:skipped].count} skipped"
  end
end
