module ApplicationHelper
  def current_agency?(client_agency_id)
    return false if current_agency.nil?

    current_agency.id.to_sym == client_agency_id.to_sym
  end

  # Render a translation that is specific to the current client agency. Define
  # client agency-specific translations as:
  #
  # foo:
  #   nyc: Some String
  #   ma: Other String
  #   default: Default String
  #
  # Then call this method with, `agency_translation("foo")` and it will attempt
  # to render the nested translation according to the client agency returned by a
  # `current_agency` method defined by your controller/mailer. If the translation
  # is either missing or there is no current client agency, it will attempt to render a
  # "default" key.
  def agency_translation(i18n_base_key, **options)
    default_key = "#{i18n_base_key}.default"
    i18n_key =
      if current_agency
        "#{i18n_base_key}.#{current_agency.id}"
      else
        default_key
      end
    is_html_key = /(?:_|\b)html\z/.match?(i18n_base_key)
    if is_html_key
      options.each do |name, value|
        next if name == :count && value.is_a?(Numeric)

        # Sanitize values being interpolated into this string.
        options[name] = ERB::Util.html_escape(value.to_s)
      end
    end

    translated =
      if I18n.exists?(scope_key_by_partial(i18n_key))
        t(i18n_key, **options)
      elsif I18n.exists?(scope_key_by_partial(default_key))
        t(default_key, **options)
      end

    # Mark as html_safe if the base key ends with `_html`.
    #
    # We have to replicate the logic from ActiveSupport::HtmlSafeTranslation
    # because the base key is the one that ends with "_html", not the one we
    # ultimately pass into the translation library.
    if is_html_key && translated.present?
      translated.html_safe
    else
      translated
    end
  end

  APPLICANT_FEEDBACK_FORM = "https://docs.google.com/forms/d/e/1FAIpQLSfrUiz0oWE5jbXjPfl-idQQGPgxKplqFtcKq08UOhTaEa2k6A/viewform"
  def feedback_form_url
    case params[:controller]
    when %r{^caseworker/}
      if current_agency && current_agency.caseworker_feedback_form.present?
        current_agency.caseworker_feedback_form
      else
        APPLICANT_FEEDBACK_FORM
      end
    else
      APPLICANT_FEEDBACK_FORM
    end
  end

  # some job statuses we consider completed even if they failed
  def coalesce_to_completed(status)
    [ :unsupported, :failed ].include?(status) ? :completed : status
  end

  def uswds_form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
    options[:builder] = UswdsFormBuilder
    options[:data] ||= {}
    options[:data][:turbo_frame] = "_top"

    turbo_frame_tag(model) do
      form_with(model: model, scope: scope, url: url, format: format, **options, &block)
    end
  end
end
