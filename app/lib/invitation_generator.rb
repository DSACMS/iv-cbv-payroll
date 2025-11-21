class InvitationGenerator
  def self.create_invite_link(client_agency_id)
    raise "❌ Can't run this in prod! ❌" if Rails.env.production?
    user = User.find_or_create_by(
      email: "ffs-eng+#{client_agency_id}@navapbc.com",
      client_agency_id: client_agency_id
    )

    user.update(is_service_account: true)
    invite = CbvFlowInvitation.new({
      user: user,
      client_agency_id: client_agency_id,
      language: "en",
      email_address: user.email,
      cbv_applicant_attributes: { first_name: "Joe", last_name: "Schmoe", client_agency_id: client_agency_id, case_number: rand(1000..9999).to_s }
    })
    invite.save!
    invite.to_url(origin: nil).gsub("https", "http")
  end
end
