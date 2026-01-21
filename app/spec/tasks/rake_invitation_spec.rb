require 'rails_helper'

RSpec.describe InvitationGenerator do
  it 'creates an invitation link for the given client agency id' do
    expect { described_class.create_invite_link('la_ldh') }.to change(CbvFlowInvitation, :count).by(1)
  end
end
