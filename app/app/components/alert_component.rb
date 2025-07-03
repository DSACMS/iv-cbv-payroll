# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  def initialize(type: :info, heading: nil, **options)
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
