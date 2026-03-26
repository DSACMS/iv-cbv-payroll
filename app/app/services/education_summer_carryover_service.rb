class EducationSummerCarryoverService
  class << self
    def applies?(terms, month_start)
      return false unless NscEnrollmentTerm.summer_month?(month_start)

      month_terms = terms_for_month(terms, month_start)
      qualifying_spring_term_for_year(terms, month_start.year).present? &&
        no_half_time_or_above_summer_terms_for_month?(month_terms)
    end

    def effective_term_for_month(terms, month_start)
      return qualifying_spring_term_for_year(terms, month_start.year) if applies?(terms, month_start)

      terms_for_month(terms, month_start).max_by(&:enrollment_priority)
    end

    def qualifying_spring_term_for_year(terms, year)
      terms.find do |term|
        term.spring_term? && term.term_end.year == year && term.half_time_or_above?
      end
    end

    private

    def terms_for_month(terms, month_start)
      terms.select { |term| term.overlaps_month?(month_start) }
    end

    def no_half_time_or_above_summer_terms_for_month?(terms_for_month)
      summer_terms = terms_for_month.select(&:summer_term?)
      return true if summer_terms.empty?

      summer_terms.none?(&:half_time_or_above?)
    end
  end
end
