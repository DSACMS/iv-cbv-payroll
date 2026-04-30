class EducationActivityProgressCalculator
  MonthHours = Struct.new(:progress, :routing, keyword_init: true)

  def initialize(education_activity)
    @education_activity = education_activity
  end

  def progress_hours_for_month(month_start)
    monthly_hours_for(month_start).progress
  end

  def routing_hours_for_month(month_start)
    monthly_hours_for(month_start).routing
  end

  private

  def monthly_hours_for(month_start)
    month = month_start.beginning_of_month

    @monthly_hours_by_month ||= @education_activity.activity_flow.reporting_months.index_with do |month_start|
      monthly_hours_for_reporting_month(month_start.beginning_of_month)
    end

    @monthly_hours_by_month[month]
  end

  def monthly_hours_for_reporting_month(month_start)
    terms = terms_for_month(month_start)

    # Buckle up, here's the logic to determine how many hours to credit the
    # user for. The routing hours may be different so that we can force the
    # user to always go back through the edit pages if necessary.
    if @education_activity.fully_self_attested?
      # For fully self-attested activities, we calculate hours based on how
      # many credit hours the user was enrolled in for that month.
      monthly_credit_hours = @education_activity.education_activity_months.find_by(month: month_start)&.hours
      MonthHours.new(
        progress: @education_activity.community_engagement_hours(monthly_credit_hours),
        routing: 0      # Always route to hours entry/doc upload pages.
      )
    elsif !@education_activity.sync_succeeded?
      # For activities where NSC failed, we return empty so that they'll be
      # treated as partially self-attested.
      MonthHours.new(progress: 0, routing: 0)
    elsif EducationSummerCarryoverService.applies?(@education_activity.nsc_enrollment_terms, month_start)
      # For activities where the summer carryover logic applies (so therefore a
      # spring term qualifies the user for the summer months), we return a
      # complete progress and routing calculation.
      MonthHours.new(
        progress: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD,
        routing: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
      )
    elsif month_has_half_time_or_above?(terms)
      # For activities where NSC returns half-time or greater, that's complete.
      MonthHours.new(
        progress: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD,
        routing: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
      )
    elsif @education_activity.partially_self_attested? && terms.present?
      # For partially self-attested activities (where the user had to
      # supplement NSC data for a given month), we compute monthly hours
      # similar to a fully self-attested activity.
      partially_self_attested_monthly_hours(terms)
    else
      MonthHours.new(progress: 0, routing: 0)
    end
  end

  def partially_self_attested_monthly_hours(terms)
    monthly_credit_hours = terms
      .select(&:less_than_half_time?)
      .sum { |term| @education_activity.review_term_credit_hours(term) }

    MonthHours.new(
      progress: @education_activity.community_engagement_hours(monthly_credit_hours),
      routing: 0
    )
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
end
