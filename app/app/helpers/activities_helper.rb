module ActivitiesHelper
  def display_progress_indicator?(progress_calculator)
    progress_calculator.result.total_hours > 0
  end
end
