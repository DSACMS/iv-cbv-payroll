class EducationActivityProgressCalculator
  def initialize(education_activity)
    @education_activity = education_activity
  end

  def progress_hours_for_month(month_start)
    return fully_self_attested_progress_hours_for_month(month_start) if @education_activity.fully_self_attested?
    return partially_self_attested_progress_hours_for_month(month_start) if @education_activity.partially_self_attested?

    validated_progress_hours_for_month(month_start)
  end

  def routing_hours_for_month(month_start)
    return 0 if @education_activity.fully_self_attested?
    return 0 unless @education_activity.sync_succeeded?

    terms = terms_for_month(month_start)
    return ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD if summer_carryover_service.applies?(month_start, terms)
    return 0 if terms.empty?

    month_has_half_time_or_above?(terms) ? ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD : 0
  end

  private

  def fully_self_attested_progress_hours_for_month(month_start)
    month = month_start.beginning_of_month
    monthly_credit_hours = @education_activity.education_activity_months.find_by(month: month)&.hours

    @education_activity.community_engagement_hours(monthly_credit_hours)
  end

  def partially_self_attested_progress_hours_for_month(month_start)
    terms = terms_for_month(month_start)
    return 0 if terms.empty?

    return ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD if month_has_half_time_or_above?(terms)

    monthly_credit_hours = terms
      .select(&:less_than_half_time?)
      .sum { |term| @education_activity.review_term_credit_hours(term) }

    @education_activity.community_engagement_hours(monthly_credit_hours)
  end

  def validated_progress_hours_for_month(month_start)
    return 0 unless @education_activity.sync_succeeded?

    terms = terms_for_month(month_start)
    return ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD if month_has_half_time_or_above?(terms)
    return ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD if summer_carryover_service.applies?(month_start, terms)

    0
  end

  def terms_for_month(month_start)
    reporting_range = @education_activity.activity_flow.reporting_window_range

    @education_activity.nsc_enrollment_terms.select do |term|
      term.within_reporting_window?(reporting_range) && term.overlaps_month?(month_start)
    end
  end

  def month_has_half_time_or_above?(terms)
    terms.any?(&:half_time_or_above?)
  end

  def summer_carryover_service
    @summer_carryover_service ||= EducationSummerCarryoverService.new(@education_activity)
  end
end
