# frozen_string_literal: true

class ActivityFlowHeaderComponentPreview < ApplicationPreview
  # @param title text
  def without_back_button(title: "Activity flow title")
    render ActivityFlowHeaderComponent.new(
      title: title,
      exit_url: "#"
    )
  end

  # @param title text
  def with_back_button(title: "Activity flow title")
    render ActivityFlowHeaderComponent.new(
      title: title,
      exit_url: "#",
      back_url: "#"
    )
  end
end
