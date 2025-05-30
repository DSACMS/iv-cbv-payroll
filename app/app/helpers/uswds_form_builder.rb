# Custom form builder. Beyond adding USWDS classes, this also
# supports setting the label, hint, and error messages by just
# using the field helpers (i.e text_field, check_box), and adds
# additional helpers like fieldset and hint.
# https://api.rubyonrails.org/classes/ActionView/Helpers/FormBuilder.html
#
# Copied from https://github.com/navapbc/pfml-starter-kit-app/blob/main/pfml/app/helpers/uswds_form_builder.rb @ 28a569a
class UswdsFormBuilder < ActionView::Helpers::FormBuilder
  standard_helpers = %i[email_field file_field password_field text_area text_field]

  def initialize(*args)
    super
    self.options[:html] ||= {}
    self.options[:html][:class] ||= "usa-form usa-form--large"
  end

  ########################################
  # Override standard helpers
  ########################################

  # Override default text fields to automatically include the label,
  # hint, and error elements
  #
  # Example usage:
  #   <%= f.text_field :foobar, { label: "Custom label text", hint: "Some hint text" } %>
  standard_helpers.each do |field_type|
    define_method(field_type) do |attribute, options = {}|
      classes = us_class_for_field_type(field_type, options[:width])
      classes += " usa-input--error" if has_error?(attribute)
      append_to_option(options, :class, " #{classes}")

      label_text = options.delete(:label)
      label_class = options.delete(:label_class) || ""

      label_options = options.except(:width, :class, :id).merge({
        class: label_class,
        for: options[:id]
      })
      field_options = options.except(:label, :hint, :label_class)

      if options[:hint]
        field_options[:aria_describedby] = hint_id(attribute)
      end

      form_group(attribute, options[:group_options] || {}) do
        us_text_field_label(attribute, label_text, label_options) + super(attribute, field_options)
      end
    end
  end

  def check_box(attribute, options = {}, *args)
    append_to_option(options, :class, " #{us_class_for_field_type(:check_box)}")

    label_text = options.delete(:label)

    @template.content_tag(:div, class: "usa-checkbox") do
      super(attribute, options, *args) + us_toggle_label("checkbox", attribute, label_text, options)
    end
  end

  def radio_button(attribute, tag_value, options = {})
    append_to_option(options, :class, " #{us_class_for_field_type(:radio_button)}")

    label_text = options.delete(:label)
    label_options = { for: field_id(attribute, tag_value) }.merge(options)

    @template.content_tag(:div, class: "usa-radio") do
      super(attribute, tag_value, options) + us_toggle_label("radio", attribute, label_text, label_options)
    end
  end

  def select(attribute, choices, options = {}, html_options = {})
    append_to_option(html_options, :class, " usa-select")

    label_text = options.delete(:label)

    form_group(attribute) do
      us_text_field_label(attribute, label_text, options) + super(attribute, choices, options, html_options)
    end
  end

  def submit(value = nil, options = {})
    append_to_option(options, :class, " usa-button")

    if options[:big]
      append_to_option(options, :class, " usa-button--big margin-y-6")
    end

    super(value, options)
  end

  ########################################
  # Custom helpers
  ########################################

  def tax_id_field(attribute, options = {})
    options[:inputmode] = "numeric"
    options[:placeholder] = "_________"
    options[:width] = "md"

    # Actual USWDS mask functionality broken until this is fixed:
    # https://github.com/uswds/uswds/issues/5517
    # append_to_option(options, :class, " usa-masked")

    append_to_option(options, :hint, @template.content_tag(:p, I18n.t("us_form_with.tax_id_format")))

    text_field(attribute, options)
  end

  def date_picker(attribute, options = {})
    raw_value = object.send(attribute) if object

    # Custom hint text
    hint_text = options.delete(:hint) || I18n.t("us_form_with.date_picker_format")
    append_to_option(options, :hint, @template.content_tag(:p, hint_text))

    group_options = options[:group_options] || {}
    append_to_option(group_options, :class, " usa-date-picker")

    if raw_value.is_a?(Date)
      append_to_option(group_options, :"data-default-value", raw_value.strftime("%Y-%m-%d"))
      value = raw_value.strftime("%m/%d/%Y") if raw_value.is_a?(Date)
    end

    text_field(attribute, options.merge(value: value, group_options: group_options))
  end

  def field_error(attribute)
    return unless has_error?(attribute)
    error_messages = object.errors.messages_for(attribute)
    error_sentence = error_messages.join("<br>").html_safe
    @template.content_tag(:span, error_sentence, class: "usa-error-message")
  end

  def fieldset(legend, options = {}, &block)
    legend_classes = "usa-legend"

    if options[:large_legend]
      legend_classes += " usa-legend--large"
    end

    form_group(options[:attribute]) do
      @template.content_tag(:fieldset, class: "usa-fieldset") do
        @template.content_tag(:legend, legend, class: legend_classes) + @template.capture(&block)
      end
    end
  end

  # Check if a field has a validation error
  def has_error?(attribute)
    return unless object
    object.errors.has_key?(attribute)
  end

  def human_name(attribute)
    return unless object
    object.class.human_attribute_name(attribute)
  end

  def hint(text)
    @template.content_tag(:div, @template.raw(text), class: "usa-hint")
  end

  def form_group(attribute = nil, options = {}, &block)
    append_to_option(options, :class, " usa-form-group")
    children = @template.capture(&block)

    if options[:show_error] or (attribute and has_error?(attribute))
      append_to_option(options, :class, " usa-form-group--error")
    end

    @template.content_tag(:div, children, options)
  end

  def yes_no(attribute, options = {})
    yes_options = options[:yes_options] || {}
    no_options = options[:no_options] || {}
    value = if object then object.send(attribute) else nil end

    yes_options = { label: I18n.t("us_form_with.boolean_true") }.merge(yes_options)
    no_options = { label: I18n.t("us_form_with.boolean_false") }.merge(no_options)

    @template.capture do
      # Hidden field included for same reason as radio button collections (https://api.rubyonrails.org/classes/ActionView/Helpers/FormOptionsHelper.html#method-i-collection_radio_buttons)
      hidden_field(attribute, value: "") +
        fieldset(options[:legend] || human_name(attribute), { attribute: attribute }) do
          buttons =
            radio_button(attribute, true, yes_options) +
              radio_button(attribute, false, no_options)

          if has_error?(attribute)
            field_error(attribute) + buttons
          else
            buttons
          end
        end
    end
  end

  def button_with_icon(value = "Button", options = {})
    button_classes = ["usa-button"]

    icon_name = options.delete(:icon)
    icon_position = options.delete(:icon_position) || :leading
    variant = options.delete(:variant)
    button_type = options.delete(:type) || 'button'
    custom_class = options.delete(:class)

    if variant
      variant = Array(variant)
      variant.each do |v|
        button_classes << "usa-button--#{v.to_s.dasherize}"
      end
    end

    all_classes = button_classes.join(" ")
    all_classes += " #{custom_class}" if custom_class
    options[:class] = all_classes
    options[:type] = button_type

    button_content_elements = []

    if icon_name
      icon_sprite_path = @template.asset_path("@uswds/uswds/dist/img/sprite.svg")
      icon_path = "#{icon_sprite_path}##{icon_name}"
      icon_wrapper_class = "usa-button__icon--#{icon_position}"

      icon_svg = @template.content_tag(:svg, class: "usa-icon", "aria-hidden": true, focusable: false, role: "img") do
        @template.tag.use("", href: icon_path)
      end

      text_span = @template.content_tag(:span, value, class: "usa-button__text")

      if icon_position == :leading
        button_content_elements << @template.content_tag(:span, icon_svg, class: icon_wrapper_class)
        button_content_elements << text_span
      else
        button_content_elements << text_span
        button_content_elements << @template.content_tag(:span, icon_svg, class: icon_wrapper_class)
      end
    else
      button_content_elements << value
    end

    @template.button_tag(button_content_elements.join.html_safe, options)
  end

  private
  def append_to_option(options, key, value)
    current_value = options[key] || ""

    if current_value.is_a?(Proc)
      options[key] = -> { current_value.call + value }
    else
      options[key] = current_value + value
    end
  end

  def us_class_for_field_type(field_type, width = nil)
    case field_type
    when :check_box
      "usa-checkbox__input usa-checkbox__input--tile"
    when :file_field
      "usa-file-input"
    when :radio_button
      "usa-radio__input usa-radio__input--tile"
    when :text_area
      "usa-textarea"
    else
      classes = "usa-input"
      classes += " usa-input--#{width}" if width
      classes
    end
  end

  # Render the label, hint text, and error message for a form field
  def us_text_field_label(attribute, text = nil, options = {})
    hint_option = options.delete(:hint)
    classes = "usa-label"
    for_attr = options[:for] || field_id(attribute)

    if options[:class]
      classes += " #{options[:class]}"
    end

    unless text
      text = human_name(attribute)
    end

    if options[:optional]
      text += @template.content_tag(:span, " (#{I18n.t('us_form_with.optional').downcase})", class: "usa-hint")
    end

    if hint_option
      if hint_option.is_a?(Proc)
        hint_content = @template.capture(&hint_option)
      else
        hint_content = @template.raw(hint_option)
      end

      hint = @template.content_tag(:div, hint_content, id: hint_id(attribute), class: "usa-hint")
    end

    label(attribute, @template.raw(text), { class: classes, for: for_attr }) + field_error(attribute) + hint
  end

  # Label for a checkbox or radio
  def us_toggle_label(type, attribute, text = nil, options = {})
    hint_text = options.delete(:hint)
    label_text = text || object.class.human_attribute_name(attribute)
    options = options.merge({ class: "usa-#{type}__label" })

    if hint_text
      hint = @template.content_tag(:span, hint_text, class: "usa-#{type}__label-description")
      label_text = "#{label_text} #{hint}".html_safe
    end

    label(attribute, label_text, options)
  end

  def hint_id(attribute)
    "#{attribute}_hint"
  end
end
