# This class handles logic related to "carrying over" the Spring enrollment
# term onto the following Summer.
#
# See EducationActivity for the definitions of "Spring" and "Summer".
class EducationSummerCarryoverService
  def initialize(education_activity)
    @education_activity = education_activity
  end

  def applies?(month_start, terms_for_month = overlapping_terms_for_month(month_start))
    return false unless NscEnrollmentTerm.summer_month?(month_start)

    qualifying_spring_term_for_year(month_start.year).present? &&
      no_half_time_or_above_summer_terms_for_month?(terms_for_month)
  end

  def effective_term_for_month(month_start, terms)
    terms_for_month = terms.select { |term| term.overlaps_month?(month_start) }
    effective_terms = terms
      .map { |term| effective_validated_term_for_month(month_start, term) }
      .compact

    effective_terms.max_by(&:enrollment_priority) ||
      (qualifying_spring_term_for_year(month_start.year) if applies?(month_start, terms_for_month))
  end

  def qualifying_spring_term_for_year(year)
    @education_activity.nsc_enrollment_terms.find do |term|
      term.spring_term? && term.term_end.year == year && term.half_time_or_above?
    end
  end

  private

  def effective_validated_term_for_month(month_start, displayed_term)
    terms_for_month = overlapping_terms_for_month(month_start)
    return displayed_term if displayed_term.overlaps_month?(month_start) && !displayed_term.summer_term?
    return displayed_term if displayed_term.overlaps_month?(month_start) && displayed_term.half_time_or_above?
    return qualifying_spring_term_for_year(month_start.year) if displayed_term.summer_term? && applies?(month_start, terms_for_month)

    displayed_term if displayed_term.overlaps_month?(month_start)
  end

  def overlapping_terms_for_month(month_start)
    @education_activity.nsc_enrollment_terms.select { |term| term.overlaps_month?(month_start) }
  end

  def no_half_time_or_above_summer_terms_for_month?(terms_for_month)
    summer_terms = terms_for_month.select(&:summer_term?)
    return true if summer_terms.empty?

    summer_terms.none?(&:half_time_or_above?)
  end
end
