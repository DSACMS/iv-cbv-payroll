module EmployerSearchTimeoutHandling
  extend ActiveSupport::Concern

  included do
    rescue_from(
      Net::ReadTimeout,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      with: :handle_employer_search_timeout
    )
  end

  private

  def handle_employer_search_timeout(exception)
    NewRelic::Agent.notice_error(exception)

    I18n.with_locale(session[:locale] || I18n.default_locale) do
      flash[:slim_alert] = {
        type: "error",
        message_html: t(employer_search_timeout_translation_key)
      }
    end

    redirect_to employer_search_timeout_redirect_path
  end

  def employer_search_timeout_translation_key
    raise NotImplementedError
  end

  def employer_search_timeout_redirect_path
    raise NotImplementedError
  end
end
