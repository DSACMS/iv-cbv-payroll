class EducationActivityCardBuilder
  include Rails.application.routes.url_helpers

  def initialize(activity:, reporting_months:)
    @activity = activity
    @reporting_months = reporting_months
  end

  def build
    return fully_self_attested_cards if @activity.fully_self_attested?

    return partially_self_attested_build if @activity.partially_self_attested?

    validated_terms = terms_for_reporting_months
    return [] if validated_terms.empty?

    [ validated_card(validated_terms) ]
  end

  private

  def fully_self_attested_cards
    months = @reporting_months.select { |month| @activity.self_attested_term_overlaps_month?(month) }
      .map { |month_start| self_attested_term_month_data(month_start) }

    [ {
      name: @activity.school_name.presence || I18n.t("activities.education.title"),
      months: months,
      edit_path: review_activities_flow_education_path(id: @activity.id, from_edit: 1)
    } ]
  end

  def self_attested_term_month_data(month_start)
    if @activity.self_attested_credit_hours_applicable?
      {
        month: month_start,
        credit_hours: @activity.credit_hours || 0,
        community_engagement_hours: @activity.community_engagement_hours(@activity.credit_hours)
      }
    else
      { month: month_start, enrollment_status: @activity.self_attested_enrollment_status_display }
    end
  end

  def partially_self_attested_cards(terms)
    terms_grouped_by_school(terms).map do |school_terms|
      {
        name: school_terms.first.school_name.presence&.titlecase || I18n.t("activities.education.title"),
        months: partially_self_attested_months_for_school(school_terms),
        edit_path: review_activities_flow_education_path(id: @activity.id, from_edit: 1)
      }
    end
  end

  def validated_card(terms)
    school_name = terms.first.school_name&.titlecase || I18n.t("activities.education.title")
    resolver = reporting_month_resolver(terms)
    months = @reporting_months.filter_map do |month_start|
      effective_term = resolver.result_for(month_start).effective_term
      next unless effective_term

      validated_month_data(month_start: month_start, effective_term: effective_term)
    end

    {
      name: school_name,
      months: months,
      edit_path: review_activities_flow_education_path(id: @activity.id, from_edit: 1)
    }
  end

  def validated_month_data(month_start:, effective_term:)
    {
      month: month_start,
      enrollment_status: effective_term.enrollment_status_display
    }
  end

  def partial_self_attested_month_data(term:, month_start:)
    {
      month: month_start,
      enrollment_status: term.enrollment_status_display
    }
  end

  def terms_grouped_by_school(terms)
    terms.group_by { |term| term.school_name.to_s.strip.downcase }.values
  end

  def partially_self_attested_months_for_school(school_terms)
    resolver = reporting_month_resolver(school_terms)
    @reporting_months.filter_map do |month_start|
      effective_term = resolver.result_for(month_start).effective_term
      next unless effective_term
      next if effective_term.less_than_half_time? && @activity.review_term_credit_hours(effective_term).zero?

      if effective_term.less_than_half_time?
        partial_self_attested_month_data(term: effective_term, month_start: month_start)
      else
        validated_month_data(month_start: month_start, effective_term: effective_term)
      end
    end
  end

  def partially_self_attested_build
    terms = terms_for_reporting_months

    return [] if terms.empty?

    partially_self_attested_cards(terms)
  end

  def terms_for_reporting_months
    reporting_month_resolver(@activity.nsc_enrollment_terms).terms_for_reporting_months
  end

  def reporting_month_resolver(terms)
    EducationReportingMonthResolver.new(terms: terms, reporting_months: @reporting_months)
  end
end
