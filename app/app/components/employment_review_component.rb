class EmploymentReviewComponent < ViewComponent::Base
  def initialize(employment_activity:, params: {})
    @employment_activity = employment_activity
    @params = params
  end

  private

  attr_reader :employment_activity, :params

  def unpaid?
    employment_activity.unpaid_or_in_kind?
  end

  def summary_partial
    unpaid? ? "activities/employment/review/unpaid_summary" : "activities/employment/review/paid_summary"
  end
end
