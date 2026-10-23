module SyncDelayAlert
  extend ActiveSupport::Concern

  included do
    helper_method :sync_delayed?
  end

  private

  def sync_delayed?
    alert_enabled?(:sync_delays) || (@payroll_account.present? && @payroll_account.created_at < 5.minutes.ago)
  end
end
