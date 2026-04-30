# Testing SFTP connections

## Testing authentication of an SFTP connection
To test that authentication works for a basic SFTP connection, you can use the following config and commands:

### 1. Start the test SFTP server
```bash
mkdir -p tmp/test-ssh-keys
ssh-keygen -t rsa -f tmp/test-ssh-keys/test-sftp
docker run -p 2222:22 -d --name sftp_test_server -v $(pwd)/tmp/test-sftp-keys/test-sftp.pub:/home/testuser/.ssh/keys/id_rsa.pub:ro atmoz/sftp testuser::1001
```

### 2. Config the app to connect to the test SFTP server
1. Edit `app/services/sftp_gateway.rb` to connect on port 2222
2. Edit `config/client-agency-config.yml` so the sandbox agency has the following:

```yaml
transmission_method: sftp
transmission_method_configuration:
  url: 127.0.0.1
  user: testuser
  private_key: "-----BEGIN OPENSSH PRIVATE KEY-----...\n...\n...\n...\n-----END OPENSSH PRIVATE KEY-----"
```

The contents of `private_key` can be computed and copied to your clipboard with this command:

```bash
cat tmp/test-sftp-keys/test-sftp | ruby -e "puts STDIN.readlines.map(&:strip).join('\n')" | pbcopy
```

### 3. Test uploading a file in the Rails Console
Open a `bin/rails console` and then within it pretend you are an SftpTransmitter:
```ruby
config = Rails.application.config.client_agencies["sandbox"].transmission_method_configuration.with_indifferent_access
sftp = SftpGateway.new(config)
sftp.upload_data(StringIO.new("foo"), "test.txt")
```

If all goes well, you should get a "Permission Denied" exception about the `testuser` not having upload permissions. That means the authentication was successful.

## Testing a full report render + transmission
This is out of date since we removed AZ DES configuration, but it's a convenient start if you need to run SFTP tests end to end.

```ruby
# Load a bunch of test stuff to make this easier
require 'factory_bot'
FactoryBot.find_definitions
require 'webmock'
include WebMock::API
WebMock.enable!
require_relative './spec/support/argyle_api_helper'
include ArgyleApiHelper
argyle_stub_request_identities_response("bob")
argyle_stub_request_paystubs_response("bob")
argyle_stub_request_gigs_response("bob")
argyle_stub_request_account_response("bob")

# Set timestamps for all the created objects, just for fidelity to how it's actually going to play out
sending_at = Date.yesterday.in_time_zone("America/Phoenix").change(hour: 8)
flows_created_at = sending_at - 12.hours

# Create some flows
Timecop.freeze(flows_created_at)
cbv_flows = 5.times.map { |i| invitation = FactoryBot.create(:cbv_flow_invitation, :az_des); FactoryBot.create(:cbv_flow, :completed, :with_argyle_account, client_agency_id: "az_des", cbv_flow_invitation: invitation, cbv_applicant: invitation.cbv_applicant) }

# link them up to test data
PayrollAccount.where(cbv_flow_id: cbv_flows).update_all(pinwheel_account_id: "019571bc-2f60-3955-d972-dbadfe0913a8")

# upload the PDFs
cbv_flows.each { |f| CaseWorkerTransmitterJob.perform_now(f.id) }

# (optional) save the CSV locally, since SFTP bucket does not allow us to download files after upload
File.open("tmp/#{flows_created_at.strftime("%Y%m%d")}_summary.csv", "w") { |f| f.write(ClientAgency::AzDes::RecentlySubmittedCasesCsv.new.generate_csv(cbv_flows)) }

# upload the report
Timecop.freeze(sending_at)
ClientAgency::AzDes::ReportDelivererJob.perform_now(flows_created_at.beginning_of_day, flows_created_at.end_of_day)
```
