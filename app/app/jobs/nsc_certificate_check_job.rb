# frozen_string_literal: true

class NscCertificateCheckJob < ApplicationJob
  queue_as :default

  def perform
    Aggregators::Sdk::NscCertificateService.new.check_and_alert!
  end
end
