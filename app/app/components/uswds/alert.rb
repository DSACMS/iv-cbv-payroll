# frozen_string_literal: true

class Uswds::Alert < ViewComponent::Base
  TYPES = %i[info warning error]

  def initialize(type: :info, heading: nil, **options)
    raise "Unsupported Alert type: #{type}" unless TYPES.include?(type.to_sym)

    @type = type
    @heading = heading
    @options = options
  end

  private

  def alert_classes
    classes = [ "usa-alert", "usa-alert--#{@type}" ]
    classes << @options[:class] if @options[:class]
    classes.join(" ")
  end
end
