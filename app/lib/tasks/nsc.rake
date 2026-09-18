# frozen_string_literal: true

namespace :nsc do
  desc "Check NSC client certificate expiration and alert if expiring soon"
  task check_certificate: :environment do
    Aggregators::Sdk::NscCertificateService.new.check_and_alert!
  end
end
