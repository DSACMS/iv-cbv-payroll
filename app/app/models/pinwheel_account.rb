class PinwheelAccount < ApplicationRecord
  belongs_to :cbv_flow

  def has_fully_synced?
    # paystubs_synced_at.present? && employment_synced_at.present? && income_synced_at.present?
    (supported_jobs.exclude?("paystubs") || paystubs_synced_at.present?) &&
    (supported_jobs.exclude?("employment") || employment_synced_at.present?) &&
    (supported_jobs.exclude?("income") || income_synced_at.present?)
  end
end
