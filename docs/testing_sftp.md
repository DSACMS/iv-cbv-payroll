This might not stay up to date, but a convenient start if you need to run SFTP tests end to end. Why it's not checked in as a ruby file:

```
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
