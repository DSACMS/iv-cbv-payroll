class PinwheelAccount < ApplicationRecord
  belongs_to :cbv_flow

  EVENTS_MAP = {
    "employment.added" => :employment_synced_at,
    "income.added" => :income_synced_at,
    "paystubs.fully_synced" => :paystubs_synced_at
  }

  EVENTS_ERRORS_MAP = {
    "employment.added" => :employment_errored_at,
    "income.added" => :income_errored_at,
    "paystubs.fully_synced" => :paystubs_errored_at
  }

  def has_fully_synced?
    (supported_jobs.exclude?("paystubs") || paystubs_synced_at.present?) &&
    (supported_jobs.exclude?("employment") || employment_synced_at.present?) &&
    (supported_jobs.exclude?("income") || income_synced_at.present?)
  end

  def job_succeeded?(job)
    error_column = EVENTS_ERRORS_MAP.select { |key| key.start_with? job }&.values.last
    return nil unless error_column.present?

    supported_jobs.include?(job) && send(error_column).blank?
  end

  def fetch_identity
    pinwheel_for(cbv_flow).fetch_identity(account_id: pinwheel_account_id)["data"]
  end

  def site_config
    Rails.application.config.sites
  end

  def pinwheel_for(cbv_flow)
    api_key = site_config[cbv_flow.site_id].pinwheel_api_token
    environment = site_config[cbv_flow.site_id].pinwheel_environment

    PinwheelService.new(api_key, environment)
  end
end
