module ClientAgency::SelectClientAgencyConfigurationClass
  def self.for(client_agency_id)
    "ClientAgency::#{client_agency_id.camelize}::Configuration".safe_constantize
  end
end
