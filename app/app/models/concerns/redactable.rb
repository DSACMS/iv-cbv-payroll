# Include this concern in models that should be redacted according to
# a data deletion policy.
#
# To configure redaction, ensure your model has a `redacted_at` datetime
# column. Then, include this module and call the class method
# `has_redactable_fields` with the fields you would like to redact, like so:
#
#   class Foo
#     has_redactable_fields case_number: :string, application_date: :date
#
#     has_many :bars
#   end
#
# Then, call the #redact! method to actually redact those fields.
module Redactable
  extend ActiveSupport::Concern

  REDACTED_TIMESTAMP_COLUMN = :redacted_at
  REDACTION_REPLACEMENTS = {
    string: "REDACTED",
    date: Date.new(1990, 1, 1),
    email: "REDACTED@example.com",
    object: {},
    uuid: "00000000-0000-0000-0000-000000000000"
  }

  included do
    scope :redacted, -> { where.not(REDACTED_TIMESTAMP_COLUMN => nil) }
    scope :unredacted, -> { where(REDACTED_TIMESTAMP_COLUMN => nil) }
  end

  class_methods do
    attr_accessor :fields_to_redact

    def has_redactable_fields(fields)
      unknown_type = fields.find { |_field, type| type != :jsonb_attributes && REDACTION_REPLACEMENTS.exclude?(type) }
      raise "Unknown redaction type for field #{unknown_type[0]}: #{unknown_type[1]}. "\
        "Valid types: #{REDACTION_REPLACEMENTS.keys + [ :jsonb_attributes ]}" if unknown_type

      @fields_to_redact = fields
    end
  end

  def redact!
    fields_to_redact = self.class.fields_to_redact || self.class.superclass.fields_to_redact
    raise "No fields to redact in #{self.class} (or its superclass)" unless fields_to_redact.present?

    fields_to_redact.each do |field, type|
      if type == :jsonb_attributes
        self[field] = redact_member_names_in_json(self[field])
      else
        self[field] = REDACTION_REPLACEMENTS[type]
      end
    end
    self[REDACTED_TIMESTAMP_COLUMN] = Time.now

    save(validate: false)
  end

  private

  def redact_member_names_in_json(json_array)
    return json_array unless json_array.is_a?(Array)

    json_array.map do |income_change|
      next income_change unless income_change.is_a?(Hash)

      income_change_copy = income_change.with_indifferent_access
      income_change_copy["member_name"] = REDACTION_REPLACEMENTS[:string] if income_change_copy.key?("member_name")
      income_change_copy
    end
  end
end
