# frozen_string_literal: true

class AdvancedLauncher::SettingComponent < ViewComponent::Base
  def initialize(title:, hint: nil)
    @title = title
    @hint = hint
  end
end
