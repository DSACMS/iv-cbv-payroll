# Include this concern in models that should be redacted according to
# a data deletion policy.
#
# To configure redaction, first, add a `redacted_at` timestamp column
# to the model. Then, include this module and call the class method
# `redact_fields` and `redact_query` like so:
#
#   class Foo
#     redact_fields case_number: :string, application_date: :date
#
#     has_many :bars
#   end
module Redactable
  extend ActiveSupport::Concern

  REDACTION_REPLACEMENTS = {
    string: "REDACTED",
    date: Date.new(1990, 1, 1),
    email: "REDACTED@example.com"
  }

  class_methods do
    attr_accessor :fields_to_redact

    def redact_fields(fields)
      unknown_type = fields.find { |_field, type| REDACTION_REPLACEMENTS.exclude?(type) }
      raise "Unknown redaction type for field #{unknown_type[0]}: #{unknown_type[1]}. "\
        "Valid types: #{REDACTION_REPLACEMENTS.keys}" if unknown_type

      @fields_to_redact = fields
    end
  end

  def redact!
    self.class.fields_to_redact.each do |field, type|
      self[field] = REDACTION_REPLACEMENTS[type]
    end

    save(validate: false)
  end
end
