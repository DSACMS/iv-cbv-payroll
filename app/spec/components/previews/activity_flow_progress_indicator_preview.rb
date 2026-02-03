# frozen_string_literal: true

class ActivityFlowProgressIndicatorPreview < ApplicationPreview
  # @param hours range { min: 0, max: 100, step: 0.5 }
  def default(hours: "31.5")
    render ActivityFlowProgressIndicator.new(
      reporting_month: Date.new(2026, 1, 1),
      hours: hours.to_f
    )
  end
end
