class EducationReportingMonthResolver
  ResolvedMonth = Struct.new(:month, :terms, :effective_term, keyword_init: true) do
    def sufficient_enrollment?
      effective_term&.half_time_or_above? || false
    end
  end

  def initialize(terms:, reporting_months:)
    @terms = terms.to_a
    @reporting_months = reporting_months.map(&:beginning_of_month)
  end

  def result_for(month_start)
    resolved_months_by_month.fetch(month_start.beginning_of_month) do
      resolved_month_for(month_start.beginning_of_month)
    end
  end

  def resolved_months
    @resolved_months ||= @reporting_months.map { |month_start| resolved_month_for(month_start) }
  end

  def terms_for_reporting_months
    (overlapping_terms_for_reporting_months + carryover_terms).uniq
  end

  private

  def resolved_months_by_month
    @resolved_months_by_month ||= resolved_months.index_by(&:month)
  end

  def resolved_month_for(month_start)
    ResolvedMonth.new(
      month: month_start,
      terms: terms_for_month(month_start),
      effective_term: EducationSummerCarryoverService.effective_term_for_month(@terms, month_start)
    )
  end

  def terms_for_month(month_start)
    @terms.select { |term| term.overlaps_month?(month_start) }
  end

  def overlapping_terms_for_reporting_months
    @terms.select do |term|
      @reporting_months.any? { |month_start| term.overlaps_month?(month_start) }
    end
  end

  def carryover_terms
    @reporting_months.filter_map do |month_start|
      next unless EducationSummerCarryoverService.applies?(@terms, month_start)

      EducationSummerCarryoverService.qualifying_spring_term_for_year(@terms, month_start.year)
    end
  end
end
