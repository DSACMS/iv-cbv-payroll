require 'rails_helper'

RSpec.describe SftpGateway do
  subject(:gateway) { described_class.new(config) }

  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }
  let(:sftp_session) { instance_double(Net::SFTP::Session, connect!: true, upload!: true, channel: channel, close_channel: true) }
  let(:channel) { instance_double(Net::SSH::Connection::Channel, eof!: true) }
  let(:local_file) { StringIO.new("pdf-content") }
  let(:remote_file_location) { "test/report.pdf" }

  before do
    allow(Net::SFTP::Session).to receive(:new).with(ssh_session).and_return(sftp_session)
  end

  describe "#upload_data" do
    context "when configured with a username and password" do
      let(:config) do
        {
          url: "sftp.example.com",
          user: "test-user",
          password: "secret"
        }
      end

      it "starts an SSH session with password authentication" do
        expect(Net::SSH).to receive(:start).with(
          "sftp.example.com",
          "test-user",
          password: "secret",
          port: 22
        ).and_return(ssh_session)

        gateway.upload_data(local_file, remote_file_location)
      end
    end

    context "when configured with a private key" do
      let(:config) do
        {
          url: "sftp.example.com",
          user: "test-user",
          private_key: "PRIVATE KEY DATA"
        }
      end

      it "starts an SSH session with key-based authentication" do
        expect(Net::SSH).to receive(:start).with(
          "sftp.example.com",
          "test-user",
          key_data: [ "PRIVATE KEY DATA" ],
          port: 22
        ).and_return(ssh_session)

        gateway.upload_data(local_file, remote_file_location)
      end
    end
  end
end
