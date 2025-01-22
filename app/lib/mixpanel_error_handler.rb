class MixpanelErrorHandler < Mixpanel::ErrorHandler
  def handle(error)
    raise error unless Rails.env.production?
    Rails.logger.error "    MixpanelErrorTracker:#{error.inspect}\n Backtrace: #{error.backtrace}"
  end
end
