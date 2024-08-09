# Include this concern in models that should be redacted according to
# a data deletion policy.
#
# To configure redaction, include this module and call the class method
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

  REDACTION_REPLACEMENTS = {
    string: "REDACTED",
    date: Date.new(1990, 1, 1),
    email: "REDACTED@example.com",
    object: {},
    uuid: "00000000-0000-0000-0000-000000000000"
  }

  class_methods do
    attr_accessor :fields_to_redact

    def has_redactable_fields(fields)
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
