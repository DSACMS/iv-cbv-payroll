# frozen_string_literal: true

class SynchronizationIndicatorComponentPreview < ApplicationPreview
  def in_progress
    render(SynchronizationIndicatorComponent.new(status: :in_progress, name: "syncing")) do
      "Syncing payroll data"
    end
  end

  def succeeded
    render(SynchronizationIndicatorComponent.new(status: :succeeded, name: "synced")) do
      "Income verified"
    end
  end

  def failed
    render(SynchronizationIndicatorComponent.new(status: :failed, name: "failed")) do
      "Connection failed"
    end
  end
end
