
module CbvFlowInvitationProvider
  def self.generate_nyc_case_number
    number = 11.times.map { rand(10) }.join
    letter = ('A'..'Z').to_a.sample
    "#{number}#{letter}"
  end

  def self.generate_nyc_client_id
    letters = 2.times.map { ('A'..'Z').to_a.sample }.join
    numbers = 5.times.map { rand(10) }.join
    last_letter = ('A'..'Z').to_a.sample
    "#{letters}#{numbers}#{last_letter}"
  end

  def self.generate_ma_agency_id
    7.times.map { rand(10) }.join
  end

  def self.generate_ma_beacon_id
    6.times.map { ('A'..'Z').to_a.sample }.join
  end
end
