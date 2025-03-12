class PayrollAccount < ApplicationRecord
  def self.sti_name
    # "PayrollAccount::Pinwheel" => "pinwheel"
    name.demodulize.downcase
  end

  def self.sti_class_for(type_name)
    # "pinwheel" => PayrollAccount::Pinwheel
    PayrollAccount.const_get(type_name.capitalize)
  end

  belongs_to :cbv_flow
  has_many :webhook_events

  private

  def find_webhook_event(event_name, event_outcome = nil)
    webhook_events.find do |webhook_event|
      webhook_event.event_name == event_name &&
        (event_outcome.nil? || webhook_event.event_outcome == event_outcome.to_s)
    end
  end
end
