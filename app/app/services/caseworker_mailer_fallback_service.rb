class CaseworkerMailerFallbackService
  SCHEMA_VALIDATION_ERROR_PATTERN = "API Specification validation failed".freeze

  def call(schema_only:)
    executions = failed_caseworker_executions
    if schema_only
      executions = executions.where("solid_queue_failed_executions.error LIKE ?", "%#{SCHEMA_VALIDATION_ERROR_PATTERN}%")
    end

    sent = 0
    skipped = []

    executions.each do |fe|
      cbv_flow_id = cbv_flow_id_from(fe)

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

      sent += 1
    end

    { sent: sent, skipped: skipped }
  end

  private

  def failed_caseworker_executions
    SolidQueue::FailedExecution
      .joins(:job)
      .where(solid_queue_jobs: { class_name: "CaseWorkerTransmitterJob" })
      .includes(:job)
  end

  def cbv_flow_id_from(failed_execution)
    failed_execution.job.arguments["arguments"][0]
  end
end
