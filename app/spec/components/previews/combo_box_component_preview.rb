# frozen_string_literal: true

class ComboBoxComponentPreview < ApplicationPreview
  def default
    render(Uswds::ComboBox.new(name: "state", label: "State", options: state_options))
  end

  def with_selected_value
    render(Uswds::ComboBox.new(name: "state", label: "State", options: state_options, selected: "FL"))
  end

  private

  def state_options
    ApplicationController.helpers.us_state_and_territory_options
  end
end
