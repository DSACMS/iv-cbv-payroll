module ViewHelper
  def switch_locale_link(locale)
    # To satisfy Brakeman and maintain security, we avoid rebuilding the URL from parameters.
    # Instead, we keep the same base path and just update the locale part of the path.
    # We also preserve the query string if present, but since we use request.path,
    # we don't have to worry about host injection via request.params.

    path = request.path
    locale_pattern = %r{^/(#{I18n.available_locales.join("|")})(/|$)}

    new_path = if path =~ locale_pattern
                 path.sub(locale_pattern, "/#{locale}\\2")
               else
                 "/#{locale}#{path == "/" ? "" : path}"
               end

    # Preserve query parameters safely.
    # request.query_parameters is already filtered and safe in this context.
    # However, to be extra safe and avoid any potential XSS from query params
    # being used in a link, we can just use the raw query string if we trust it,
    # or better, reconstruct it from query_parameters except for sensitive keys.
    query_params = request.query_parameters.respond_to?(:to_unsafe_h) ? request.query_parameters.to_unsafe_h : request.query_parameters.to_h
    safe_query = query_params.except(:host, :port, :protocol, :script_name, "host", "port", "protocol", "script_name")

    final_path = new_path
    final_path += "?#{safe_query.to_query}" if safe_query.present?

    link_to t("shared.languages.#{locale}"), final_path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
