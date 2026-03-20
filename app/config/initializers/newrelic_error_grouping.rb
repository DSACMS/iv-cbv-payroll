NewRelic::Agent.set_error_group_callback(proc do |chain_hash|
  if chain_hash[:'error.message']&.include?("properties which are not allowed by the schema")
    "agency-api-schema-validation-error"
  end
end)
