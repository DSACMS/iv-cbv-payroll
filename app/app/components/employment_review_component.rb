class EmploymentReviewComponent < ViewComponent::Base
  def initialize(employment_activity:, flow:, params: {})
    @employment_activity = employment_activity
    @flow = flow
    @params = params
    @unpaid = employment_activity.unpaid_or_in_kind?
  end

  private

  attr_reader :employment_activity, :flow, :params

  def unpaid?
    @unpaid
  end

  def summary_partial
    unpaid? ? "activities/employment/review/unpaid_summary" : "activities/employment/review/paid_summary"
  end
end
