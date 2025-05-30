class PayrollAccount < ApplicationRecord
  def self.sti_name
    # "PayrollAccount::Pinwheel" => "pinwheel"
    name.demodulize.downcase
  end

  def self.sti_class_for(type_name)
    # "pinwheel" => PayrollAccount::Pinwheel
    PayrollAccount.const_get(type_name.capitalize)
  end

  belongs_to :cbv_flow
  has_many :webhook_events

  enum :synchronization_status, {
    unknown: "unknown",              # defines the method: sync_unknown?
    in_progress: "in_progress",      # defines the method: sync_in_progress?
    succeeded: "succeeded",          # defines the method: sync_succeeded?
    failed: "failed"                 # defines the method: sync_failed?
  }, prefix: "sync"

  # Returns whether we have received all expected webhooks for the sync
  # process, regardless of whether any of them are errors.
  #
  # To determine whether the sync was ultimately successful, use the value of
  # the `synchronization_status` column (via `sync_succeeded?`).
  def has_fully_synced?
    raise NotImplementedError
  end

  # Returns whether the job was successful.
  def job_succeeded?(job)
    raise NotImplementedError
  end

  # Returns the status of the job. Valid return values are:
  #   :unsupported - The job is not supported for this account.
  #   :succeeded   - The job completed successfully.
  #   :failed      - The job completed with an error.
  #   :in_progress - The job has not yet completed.
  def job_status(job)
    raise NotImplementedError
  end

  # Returns whether the minimal set of webhooks succeeded.
  #
  # This is an early way to bail out of even fetching the report if we know the
  # data is not going to be present.
  def necessary_jobs_succeeded?
    raise NotImplementedError
  end

  # Redact data associated with this PayrollAccount when triggered by the
  # DataRetentionService.
  def redact!
    raise NotImplementedError
  end

  private

  def find_webhook_event(event_name, event_outcome = nil)
    webhook_events.find do |webhook_event|
      webhook_event.event_name == event_name &&
        (event_outcome.nil? || webhook_event.event_outcome == event_outcome.to_s)
    end
  end
end
