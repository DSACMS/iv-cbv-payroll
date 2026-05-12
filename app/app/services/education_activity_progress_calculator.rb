class EducationActivityProgressCalculator
  MonthHours = Struct.new(:progress, :routing, :sufficient_enrollment, keyword_init: true)

  def initialize(education_activity)
    @education_activity = education_activity
  end

  def progress_hours_for_month(month_start)
    monthly_hours_for(month_start).progress
  end

  def routing_hours_for_month(month_start)
    monthly_hours_for(month_start).routing
  end

  def sufficient_enrollment_for_month?(month_start)
    !!monthly_hours_for(month_start).sufficient_enrollment
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
    resolved_month = reporting_month_resolver.result_for(month_start)
    terms = resolved_month.terms

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
    elsif resolved_month.sufficient_enrollment?
      # Half-time-or-greater NSC enrollment, including spring carryover for summer months, is complete.
      MonthHours.new(
        progress: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD,
        routing: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD,
        sufficient_enrollment: true
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

  def reporting_month_resolver
    @reporting_month_resolver ||= EducationReportingMonthResolver.new(
      terms: @education_activity.nsc_enrollment_terms,
      reporting_months: @education_activity.activity_flow.reporting_months
    )
  end
end
