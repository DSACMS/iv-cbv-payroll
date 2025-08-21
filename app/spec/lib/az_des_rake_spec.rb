require "rails_helper"

RSpec.describe "az_des.rake" do
  before do
    ActiveJob::Base.queue_adapter = :test
    Rake::Task["az_des:deliver_csv_reports"].reenable
  end

  it "does not enqueue the CSV job when csv_summary_reports_enabled is false" do
    allow(ClientAgency::AzDes::Configuration).to receive(:sftp_transmission_configuration).and_return(
      { "csv_summary_reports_enabled" => false }
    )

    expect { Rake::Task["az_des:deliver_csv_reports"].execute }.
      not_to have_enqueued_job(ClientAgency::AzDes::ReportDelivererJob)
  end

  it "enqueues the CSV job when csv_summary_reports_enabled is true" do
    allow(ClientAgency::AzDes::Configuration).to receive(:sftp_transmission_configuration).and_return(
      { "csv_summary_reports_enabled" => true }
    )

    expect { Rake::Task["az_des:deliver_csv_reports"].execute }.
      to have_enqueued_job(ClientAgency::AzDes::ReportDelivererJob)
  end
end
