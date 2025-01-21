class HelpAlertComponent < ViewComponent::Base
  def initialize(visible: false, help_path: nil)
    @visible = visible
    @help_path = help_path
  end

  private

  def visible?
    @visible
  end

  def help_path
    @help_path
  end
end
