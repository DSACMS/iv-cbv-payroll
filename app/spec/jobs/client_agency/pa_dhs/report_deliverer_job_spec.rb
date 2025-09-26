require 'rails_helper'
require 'csv'

RSpec.describe ClientAgency::PaDhs::ReportDelivererJob, type: :job do
  let(:sftp_gateway) { instance_double(SftpGateway) }
  before do
    allow(SftpGateway).to receive(:new).and_return(sftp_gateway)
  end

  context "#perform" do
    context 'when client is pa_dhs' do
      it "generates csv when there is a case that has been submitted during time period specified" do
        authorized_timestamp = Time.find_zone("UTC").local(2025, 1, 1, 10)
        transmitted_at = Time.find_zone("UTC").local(2025, 5, 1, 1)
        cbv_flow = create(:cbv_flow, :completed, :invited, client_agency_id: "pa_dhs",
                          consented_to_authorized_use_at: authorized_timestamp,
                          transmitted_at: transmitted_at)
        cbv_flow.cbv_applicant.update!(case_number: "12345")

        allow(ClientAgency::PaDhs::Configuration).to receive(:sftp_transmission_configuration).and_return(
          {
            "sftp_directory" => "test"
          }
        )

        expect(sftp_gateway).to receive(:upload_data) do |raw_csv, filename|
          expect(filename).to eq('test/20250401_summary.csv')
          csv = CSV.parse(raw_csv, headers: true)
          expect(csv.headers).to eq([ "case_number", "confirmation_code", "cbv_link_created_timestamp", "cbv_link_clicked_timestamp", "report_created_timestamp", "consent_timestamp", "pdf_filename", "pdf_filetype", "language" ])
          row = csv.first
          expect(row["case_number"]).to eq("12345")
          expect(row["consent_timestamp"]).to eq("01/01/2025 05:00:00")
          expect(row["pdf_filename"]).to eq("CBVPilot_00012345_20250101_ConfSANDBOX0010002.pdf")
        end

        described_class.perform_now(Date.new(2025, 4, 1), Date.new(2025, 5, 2))
      end
    end

    it "does not generate csv when there is no case that has been submitted during time period specified - pa_dhs" do
      create(:cbv_flow, :completed, :invited, client_agency_id: "pa_dhs", transmitted_at: 11.minutes.ago)
      create(:cbv_flow, :completed, :invited, client_agency_id: "sandbox", transmitted_at: 4.minutes.ago)

      expect(sftp_gateway).not_to receive(:upload_data)

      described_class.perform_now(10.minutes.ago, Time.current)
    end
  end
end
