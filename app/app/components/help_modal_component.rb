class HelpModalComponent < ViewComponent::Base
  def initialize(open: false, help_path: nil)
    @open = open
    @help_path = help_path
  end

  private

  def modal_id
    "help-modal"
  end

  def open?
    @open
  end

  def help_path
    @help_path
  end
end
