# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create test API key for JSON API receiver
user = User.find_or_create_by(
  client_agency_id: "sandbox",
  is_service_account: true,
  email: "ffs-eng+info@digitalpublicworks.org"
)

unless user.api_access_tokens.exists?(access_token: "test-api-key")
  token = user.api_access_tokens.build
  token.access_token = "test-api-key"
  token.save!
  puts "Created test API key: test-api-key"
end
