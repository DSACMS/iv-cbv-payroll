require 'rails_helper'

RSpec.describe Transmitters::SftpTransmitter do
  subject(:transmitter) { described_class.new(cbv_flow, client_agency, aggregator_report) }

  let(:client_agency) do
    instance_double(ClientAgencyConfig::ClientAgency)
  end

  let(:transmission_method_configuration) do
    {
      "url" => "sftp.example.com",
      "user" => "test-user",
      "password" => "secret",
      "sftp_directory" => "test"
    }
  end
  let(:cbv_flow) { create(:cbv_flow) }
  let(:aggregator_report) { build(:argyle_report, :with_argyle_account) }
  let(:sftp_gateway) { instance_double(SftpGateway, upload_data: true) }
  let(:formatted_filename) { "formatted_filename" }

  before do
    allow(client_agency).to receive_messages(
      transmission_method_configuration: transmission_method_configuration,
      transmission_method: described_class::TRANSMISSION_METHOD
    )
    allow(SftpGateway).to receive(:new).and_return(sftp_gateway)
    allow(Transmitters::PdfFilenameFormatter).to receive(:format).and_return(formatted_filename)
  end

  it_behaves_like "Transmitters::BasePdfTransmitter"

  describe "#pdf_filename_format" do
    subject(:pdf_filename_format) { transmitter.send(:pdf_filename_format) }

    it "returns the default format when no custom format is configured" do
      expect(pdf_filename_format).to eq(described_class::DEFAULT_PDF_FILENAME_FORMAT)
    end

    context "when a custom pdf filename format is configured" do
      let(:transmission_method_configuration) do
        super().merge("pdf_filename_format" => "CBV_%{case_number}_%{consent_timestamp}_%{confirmation_code}.pdf")
      end

      it "returns the configured format" do
        expect(pdf_filename_format).to eq("CBV_%{case_number}_%{consent_timestamp}_%{confirmation_code}.pdf")
      end
    end
  end

  describe "#deliver" do
    include_context "with #pdf_output" do
      let(:pdf_output) do
        PdfService::PdfGenerationResult.new(
          "dummy_pdf_content",
          "dummy_html_content",
          1,
          17,
        )
      end
    end

    before do
      cbv_flow.update!(
        confirmation_code: "SANDBOX001",
        consented_to_authorized_use_at: Time.zone.parse("2025-01-01 08:00:30")
      )
    end

    context "when a custom pdf filename format is configured" do
      let(:transmission_method_configuration) do
        super().merge("pdf_filename_format" => "chosen_format")
      end

      it "passes the selected format to PdfFilenameFormatter" do
        expect(Transmitters::PdfFilenameFormatter).to receive(:format).with(
          cbv_flow,
          "chosen_format"
        ).and_return(formatted_filename)

        expect(sftp_gateway).to receive(:upload_data).with(
          an_instance_of(StringIO),
          "test/formatted_filename.pdf"
        )

        transmitter.deliver
      end
    end

    context "when the agency uses username and password authentication" do
      it "passes the password-based config through to the gateway" do
        expect(SftpGateway).to receive(:new).with(
          hash_including(
            "url" => "sftp.example.com",
            "user" => "test-user",
            "password" => "secret",
            "sftp_directory" => "test"
          )
        ).and_return(sftp_gateway)

        expect(sftp_gateway).to receive(:upload_data).with(
          an_instance_of(StringIO),
          "test/formatted_filename.pdf"
        )

        transmitter.deliver
      end
    end

    context "when the agency uses SSH key authentication" do
      let(:transmission_method_configuration) do
        {
          "url" => "sftp.example.com",
          "user" => "test-user",
          "private_key" => "PRIVATE KEY DATA",
          "sftp_directory" => "test"
        }
      end

      it "passes the key-based config through to the gateway" do
        expect(SftpGateway).to receive(:new).with(
          hash_including(
            "url" => "sftp.example.com",
            "user" => "test-user",
            "private_key" => "PRIVATE KEY DATA",
            "sftp_directory" => "test"
          )
        ).and_return(sftp_gateway)

        expect(sftp_gateway).to receive(:upload_data).with(
          an_instance_of(StringIO),
          "test/formatted_filename.pdf"
        )

        transmitter.deliver
      end
    end
  end
end
