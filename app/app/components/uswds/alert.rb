# frozen_string_literal: true

class Uswds::Alert < ViewComponent::Base
  TYPES = %i[success info warning error]

  def initialize(type: :info, heading: nil, slim: false, form_id: nil, dismiss_key: nil, **options)
    raise "Unsupported Alert type: #{type}" unless TYPES.include?(type.to_sym)

    @type = type
    @heading = heading
    @slim = slim
    @form_id = form_id
    @dismiss_key = dismiss_key
    @options = options
  end

  private

  def controllers
    [ ("dismissible-alert" if @dismiss_key.present?), ("error-summary" if @form_id.present?) ].compact.join(" ")
  end

  def alert_classes
    classes = [ "usa-alert", "usa-alert--#{@type}" ]
    classes << @options[:class] if @options[:class]
    classes << "usa-alert--slim" if @slim
    classes.join(" ")
  end
end
