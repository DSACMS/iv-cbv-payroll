module ApplicationHelper
  def current_site?(site)
    @current_site.id.to_sym == site
  end

  # Thread safe getter for the
  def self.current_site
    Thread.current[:current_site]
  end

  def self.current_site=(site)
    Thread.current[:current_site] = site
    site
  end

  # Render a translation that is specific to the current site. Define
  # site-specific translations as:
  #
  # foo:
  #   nyc: Some String
  #   ma: Other String
  #   default: Default String
  #
  # Then call this method with, `site_translation("foo")` and it will attempt
  # to render the nested translation according to the site returned by a
  # `current_site` method defined by your controller/mailer. If the translation
  # is either missing or there is no current site, it will attempt to render a
  # "default" key.
  def site_translation(i18n_base_key, **options)
    default_key = "#{i18n_base_key}.default"
    i18n_key =
      if current_site
        "#{i18n_base_key}.#{current_site.id}"
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
      if current_site && current_site.caseworker_feedback_form
        current_site.caseworker_feedback_form
      else
        APPLICANT_FEEDBACK_FORM
      end
    else
      APPLICANT_FEEDBACK_FORM
    end
  end
end
