class PayrollAccount < ApplicationRecord
  self.table_name = "pinwheel_accounts"

  belongs_to :cbv_flow

  after_update_commit {
    I18n.with_locale(cbv_flow.cbv_flow_invitation.language) do
      broadcast_replace target: self, partial: "cbv/synchronizations/indicators", locals: { pinwheel_account: self }
    end
  }

  EVENTS_MAP = {
    "employment.added" => :employment_synced_at,
    "income.added" => :income_synced_at,
    "identity.added" => :identity_synced_at,
    "paystubs.fully_synced" => :paystubs_synced_at
  }

  EVENTS_ERRORS_MAP = {
    "employment.added" => :employment_errored_at,
    "income.added" => :income_errored_at,
    "identity.added" => :identity_errored_at,
    "paystubs.fully_synced" => :paystubs_errored_at
  }

  def has_fully_synced?
    (supported_jobs.exclude?("paystubs") || paystubs_synced_at.present?) &&
    (supported_jobs.exclude?("employment") || employment_synced_at.present?) &&
    (supported_jobs.exclude?("income") || income_synced_at.present?) &&
    (supported_jobs.exclude?("identity") || identity_synced_at.present?)
  end

  def job_succeeded?(job)
    error_column, sync_column = event_columns_for(job)
    return nil unless error_column.present?

    supported_jobs.include?(job) && send(sync_column).present? && send(error_column).blank?
  end

  def synchronization_status(job)
    error_column, sync_column = event_columns_for(job)
    return nil unless error_column.present?

    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif supported_jobs.include?(job) && (send(sync_column).blank? && send(error_column).blank?)
      :in_progress
    elsif supported_jobs.include?(job) && (send(error_column).present?)
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs")
  end

  private

  def event_columns_for(job)
    error_column = EVENTS_ERRORS_MAP.select { |key| key.start_with? job }&.values.last
    sync_column = EVENTS_MAP.select { |key| key.start_with? job }&.values.last

    [ error_column, sync_column ]
  end
end
