# frozen_string_literal: true

class HelpAlertComponent < ViewComponent::Base
  def initialize(visible: false, help_path: nil)
    @visible = visible
    @help_path = help_path
  end

  def visible?
    @visible
  end

  private

  attr_reader :help_path
end
