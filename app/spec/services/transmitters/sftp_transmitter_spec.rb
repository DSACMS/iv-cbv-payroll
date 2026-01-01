require 'rails_helper'

RSpec.describe Transmitters::SftpTransmitter do
  let(:client_agency) do
    instance_double(ClientAgencyConfig::ClientAgency)
  end

  let(:cbv_flow) { create(:cbv_flow) }
  let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }

  subject do
    described_class.new(cbv_flow, client_agency, aggregator_report)
  end

  include_examples "Transmitters::BasePdfTransmitter"
end
