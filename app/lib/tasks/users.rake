namespace :users do
  desc "Promote an existing account to service account status, returning an access token"
  task promote_to_service_account: :environment do
    user = User.find(ENV["id"])

    if user && user.update(is_service_account: true)
      token = user.api_access_tokens.create

      puts "User #{ENV["id"]} (#{user.email}) is now a service account: #{token.access_token}"
    end
  end

  desc "Demote an existing account, deleting all associated access tokens"
  task demote_service_account: :environment do
    user = User.find(ENV["id"])

    if user && user.update(is_service_account: false)
      user.api_access_tokens.destroy_all

      puts "User #{ENV["id"]} (#{user.email}) is no longer a service account."
    end
  end
end
