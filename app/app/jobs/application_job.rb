class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def event_logger
    @event_logger ||= GenericEventTracker.new
  end
end
