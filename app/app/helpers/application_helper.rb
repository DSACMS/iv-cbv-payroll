module ApplicationHelper
  # Render a translation that is specific to the current site. Define
  # site-specific translations as:
  #
  # foo:
  #   nyc: Some String
  #   ma: Other String
  #   default: Default String
  #
  # Then call this method with, `site_translation("foo")` and it will attempt
  # to render the nested translation according to the current site ID, or use
  # the "default" string if the translation is either missing or there is no
  # current site.
  def site_translation(i18n_base_key, **options)
    default_key = "#{i18n_base_key}.default"
    i18n_key =
      if current_site
        "#{i18n_base_key}.#{current_site.id}"
      else
        default_key
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
    if /(?:_|\b)html\z/.match?(i18n_base_key) && translated.present?
      translated.html_safe
    else
      translated
    end
  end
end
