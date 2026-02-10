module ActivitiesHelper
  def display_progress_indicator?(progress_calculator)
    progress_calculator.overall_result.total_hours > 0
  end
end
