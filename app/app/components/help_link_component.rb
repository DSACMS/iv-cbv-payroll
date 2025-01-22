# frozen_string_literal: true

class HelpLinkComponent < ViewComponent::Base
  def initialize(class_name: nil, text: nil)
    @class_name = class_name
    @text = text
  end

  def before_render
    @text ||= t("help.alert.help_options")
  end

  private

  attr_reader :class_name, :text
end 