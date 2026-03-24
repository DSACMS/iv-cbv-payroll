class EducationActivityCardBuilder
  def initialize(activity:, reporting_months:, view_context:)
    @activity = activity
    @reporting_months = reporting_months
    @view_context = view_context
  end

  def build
    return fully_self_attested_cards if @activity.fully_self_attested?

    return partially_self_attested_build if @activity.partially_self_attested?

    validated_terms = validated_terms_for_reporting_months
    return [] if validated_terms.empty?

    [ validated_card(validated_terms) ]
  end

  private

  def fully_self_attested_cards
    months_by_date = @activity.education_activity_months.index_by(&:month)
    months = @reporting_months.reverse.map do |month_start|
      activity_month = months_by_date[month_start.beginning_of_month]
      self_attested_month_data(activity_month: activity_month, month_start: month_start)
    end

    [ {
      name: @activity.school_name.presence || I18n.t("activities.education.title"),
      months: months,
      edit_path: @view_context.edit_activities_flow_education_month_path(education_id: @activity.id, id: 0, from_edit: 1)
    } ]
  end

  def partially_self_attested_cards(overlapping_terms)
    overlapping_terms.map do |term|
      school_name = term.school_name&.titlecase || I18n.t("activities.education.title")
      visible_months = @reporting_months.reverse.select { |month_start| term.overlaps_month?(month_start) }
      months = visible_months.map do |month_start|
        if term.less_than_half_time?
          partial_self_attested_month_data(term: term, month_start: month_start)
        else
          validated_month_data(month_start: month_start, effective_term: term)
        end
      end

      {
        name: school_name,
        months: months,
        edit_path: @view_context.edit_activities_flow_education_term_credit_hour_path(
          education_id: @activity.id,
          id: less_than_half_time_term_index(term)
        )
      }
    end
  end

  def validated_card(overlapping_terms)
    school_name = overlapping_terms.first.school_name&.titlecase || I18n.t("activities.education.title")
    months = @reporting_months.reverse.map do |month_start|
      effective_term = summer_carryover_service.effective_term_for_month(month_start, overlapping_terms)
      validated_month_data(month_start: month_start, effective_term: effective_term)
    end

    {
      name: school_name,
      months: months,
      edit_path: @view_context.edit_activities_flow_education_path(id: @activity.id)
    }
  end

  def validated_month_data(month_start:, effective_term:)
    {
      month: month_start,
      enrollment_status: effective_term ? effective_term.enrollment_status_display : I18n.t("activities.hub.cards.not_enrolled"),
      community_engagement_hours: effective_term&.half_time_or_above? ? ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD : 0,
      credit_hours: nil,
      show_credit_hours: false
    }
  end

  def partial_self_attested_month_data(term:, month_start:)
    credit_hours = @activity.review_term_credit_hours(term)
    {
      month: month_start,
      enrollment_status: term.enrollment_status_display,
      community_engagement_hours: @activity.community_engagement_hours(credit_hours),
      credit_hours: credit_hours,
      show_credit_hours: true
    }
  end

  def self_attested_month_data(activity_month:, month_start:)
    credit_hours = education_credit_hours(activity_month)
    {
      month: month_start,
      credit_hours: credit_hours,
      community_engagement_hours: @activity.community_engagement_hours(credit_hours)
    }
  end

  def education_credit_hours(activity_month)
    return 0 unless activity_month
    return activity_month.credit_hours.to_i if activity_month.has_attribute?(:credit_hours)

    activity_month.hours.to_i
  end

  def less_than_half_time_term_index(term)
    @activity.less_than_half_time_terms_in_reporting_window
      .index { |less_than_half_time_term| less_than_half_time_term.id == term.id } || 0
  end

  def partially_self_attested_build
    overlapping_terms = @activity.nsc_enrollment_terms
      .select { |term| @reporting_months.any? { |month_start| term.overlaps_month?(month_start) } }

    return [] if overlapping_terms.empty?

    partially_self_attested_cards(overlapping_terms)
  end

  def validated_terms_for_reporting_months
    overlapping_terms = @activity.nsc_enrollment_terms
      .select { |term| @reporting_months.any? { |month_start| term.overlaps_month?(month_start) } }
    carryover_terms = @reporting_months.filter_map do |month_start|
      next unless summer_carryover_service.applies?(month_start)

      summer_carryover_service.qualifying_spring_term_for_year(month_start.year)
    end

    (overlapping_terms + carryover_terms).uniq
  end

  def summer_carryover_service
    @summer_carryover_service ||= EducationSummerCarryoverService.new(@activity)
  end
end
