# This class compares two sets of names as outlined in:
#   https://confluenceent.cms.gov/x/iDy8PQ
#
# A match result will be computed for each name in `source_names_list`
# against all the names in the `target_names_list`.
class AgencyNameMatchingService
  # Sorted worst -> best:
  NAME_MATCH_LEVELS = %i[
    none
    approximate
    close
    exact
  ].freeze

  def initialize(source_names_list, target_names_list)
    @source_names_list = normalize_name_list(source_names_list)
    @target_names_list = normalize_name_list(target_names_list)
  end

  def match_results
    @source_names_list.each_with_object(
      exact_match_count: 0,
      close_match_count: 0,
      approximate_match_count: 0,
      none_match_count: 0
    ) do |source_name, results|
      best_match = @target_names_list.max_by do |target_name|
        NAME_MATCH_LEVELS.index(match_names(source_name, target_name))
      end

      case match_names(source_name, best_match)
      when :exact
        results[:exact_match_count] += 1
      when :close
        results[:close_match_count] += 1
      when :approximate
        results[:approximate_match_count] += 1
      when :none
        results[:none_match_count] += 1
      else
        raise "Unknown match type"
      end
    end
  end

  private

  def match_names(name_one, name_two)
    if (name_one & name_two) == name_one || (name_two & name_one) == name_two
      :exact
    elsif (name_one & name_two).length >= 2
      :close
    elsif (name_one & name_two).length == 1
      :approximate
    else
      :none
    end
  end

  def normalize_name_list(name_list)
    name_list.uniq.map do |name|
      name
        .split(/[^a-z]+/i)
        .keep_if { |s| s.length > 1 }
    end
  end
end
