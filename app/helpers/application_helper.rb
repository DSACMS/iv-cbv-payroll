module ApplicationHelper
  def format_active_locale(locale_string)
    link_classes = "usa-nav__link"
    if locale_string.to_sym == I18n.locale
      link_classes = "#{link_classes} usa-current"
    end
    link_to t("shared.languages.#{locale_string}"), root_path(locale: locale_string), class: link_classes
  end
end
