namespace :users do
  desc "Redact data that is older than our retention policy"
  task promote_to_service_account: :environment do
    user = User.find(ENV["id"])

    if user && user.update(is_service_account: true)
      token = user.api_access_tokens.create

      puts "User #{ENV["id"]} (#{user.email_address}) is now a service account: #{token.access_token}"
    end
  end

  task demote_service_account: :environment do
    user = User.find(ENV["id"])

    if user && user.update(is_service_account: false)
      user.api_access_tokens.destroy_all

      puts "User #{ENV["id"]} (#{user.email_address}) is no longer a service account."
    end
  end
end
