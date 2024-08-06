class PinwheelAccount < ApplicationRecord
  belongs_to :cbv_flow

  def has_full_synced?
    paystubs_synced_at.present? && employment_synced_at.present? && income_synced_at.present?
  end
end
