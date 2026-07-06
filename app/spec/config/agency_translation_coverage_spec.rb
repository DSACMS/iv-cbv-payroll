require "rails_helper"

# Guards against a class of bug where a new client agency is added to
# client-agency-config.yml (and/or a locale file is copied from another agency)
# but the agency-scoped translation keys are never defined for it. Because
# `ApplicationHelper#agency_translation` falls back to `.<agency_id>` ->
# `.default` -> nil, a missing key renders as a blank string in the flow instead
# of raising, so it slips through unnoticed. See the Accenture regression and
# PR #1834.
RSpec.describe "agency translation coverage" do # rubocop:disable RSpec/DescribeClass
  let(:agency_ids) { Rails.application.config.client_agencies.client_agency_ids }

  # A translation node is "agency-scoped" when at least one of its immediate
  # children is a known agency id. For such a node, a given agency id is
  # required only when *every other* agency already defines it (i.e. it is a
  # shared string, not an agency-specific override). A node with a `default`
  # child is always satisfied via the fallback path.
  def missing_agency_translations(node, path, agency_ids, missing)
    return unless node.is_a?(Hash)

    keys = node.keys.map(&:to_s)
    if (keys & agency_ids).any? && !keys.include?("default")
      agency_ids.each do |agency_id|
        next if keys.include?(agency_id)
        next unless (agency_ids - [ agency_id ]).all? { |other| keys.include?(other) }

        missing << "#{path.join('.')}.#{agency_id}"
      end
    end

    node.each { |key, value| missing_agency_translations(value, path + [ key.to_s ], agency_ids, missing) }
  end

  I18n.available_locales.each do |locale|
    it "defines every shared agency-scoped key for all agencies in #{locale}.yml" do
      tree = YAML.unsafe_load_file(Rails.root.join("config", "locales", "#{locale}.yml")).fetch(locale.to_s)

      missing = []
      missing_agency_translations(tree, [ locale.to_s ], agency_ids, missing)

      expect(missing).to be_empty, <<~MSG
        Missing agency-scoped translations in config/locales/#{locale}.yml.
        Every agency that shares these keys must define them (or the key needs a `default`):

        #{missing.sort.join("\n")}
      MSG
    end
  end
end
