class EnrollmentDetailsComponent < ViewComponent::Base
  def initialize(enrollment_terms:)
    @enrollment_groups = enrollment_terms
      .group_by { |term| [ term.school_name, term.term_begin, term.term_end ] }
      .values
      .map do |terms|
        terms.sort_by { |term| [ term.school_certified_on || Date.new(1, 1, 1), term.id || 0 ] }.reverse
      end
  end
end
