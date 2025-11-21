require 'rails_helper'

RSpec.describe InvitationGenerator do
  it 'creates an invitation link for the given client agency id' do
    expect { Rake::Task["invitation:create"].execute(client_agency_id: 'la_ldh') }.to change(CbvFlowInvitation, :count).by(1)
  end
end
