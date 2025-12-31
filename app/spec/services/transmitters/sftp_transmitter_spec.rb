require 'rails_helper'

RSpec.describe Transmitters::SftpTransmitter do
  include_examples "Transmitters::PdfTransmitter"
end
