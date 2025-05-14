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

  def date_string_to_date(date_string)
    date_string.is_a?(Date) ? date_string : Date.parse(date_string)
  rescue
    nil
  end

  def get_age_range(date_of_birth)
    dob = date_string_to_date(date_of_birth)
    return nil unless dob

    today = Date.today
    age = today.year - dob.year
    this_years_birthday = Date.new(today.year, dob.month, dob.day)

    # Subtract 1 if birthday hasn't occurred yet this year
    age -= 1 if today < this_years_birthday

    case age
    when 0..18 then "0-18"
    when 18..25 then "18-25"
    when 26..29 then "26-29"
    when 30..39 then "30-39"
    when 40..49 then "40-49"
    when 50..54 then "50-54"
    when 55..59 then "55-59"
    when 60..64 then "60-64"
    when 65..69 then "65-69"
    when 70..74 then "70-74"
    when 75..79 then "75-79"
    when 80..89 then "80-89"
    else "90+"
    end
  end
end
