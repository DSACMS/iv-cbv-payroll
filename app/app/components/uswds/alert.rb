# frozen_string_literal: true

class Uswds::Alert < ViewComponent::Base
  TYPES = %i[success info warning error]

  def initialize(type: :info, heading: nil, slim: false, autofocus: false,**options)
    raise "Unsupported Alert type: #{type}" unless TYPES.include?(type.to_sym)

    @type = type
    @heading = heading
    @slim = slim
    @autofocus = autofocus
    @options = options
  end

  private

  def alert_classes
    classes = [ "usa-alert", "usa-alert--#{@type}" ]
    classes << @options[:class] if @options[:class]
    classes << "usa-alert--slim" if @slim
    classes.join(" ")
  end
end
