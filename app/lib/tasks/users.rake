namespace :users do
  desc "Promote an existing account to service account status, returning an access token"
  task promote_to_service_account: :environment do
    ActiveRecord::Base.transaction do
      user = User.find(ENV["id"])
      puts "Found user #{user.id} with #{user.api_access_tokens.count} existing tokens"

      if user && user.update(is_service_account: true)
        puts "Updated user to service account"
        user.api_access_tokens.create!
        puts "Created new token"

        puts "User #{ENV["id"]} (#{user.email}) is now a service account"
        puts "User now has #{user.api_access_tokens.count} tokens"
      end
    end
  end

  desc "Demote an existing account, deleting all associated access tokens"
  task demote_service_account: :environment do
    user = User.find(ENV["id"])

    if user && user.update(is_service_account: false)
      user.api_access_tokens.update_all(deleted_at: Time.now)

      puts "User #{ENV["id"]} (#{user.email}) is no longer a service account."
    end
  end
end
