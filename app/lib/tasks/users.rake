namespace :users do
  # bin/rails 'users:create_api_token[la_ldh]'
  desc "Creates an API token for a client agency, and user if necessary."
  task :create_api_token, [ :client_agency_id ] => [ :environment ] do |_, args|
    client_agency_id = args[:client_agency_id]

    user = User
      .where(client_agency_id: client_agency_id, is_service_account: true)
      .create_with(email: "ffs-eng+#{client_agency_id}@digitalpublicworks.org")
      .first_or_create

    token = user.api_access_tokens.create
    puts "User #{user.id} (#{user.email}) has new API token: #{token.access_token}"
  end

  # bin/rails 'users:promote_to_service_account[2]'
  desc "Promote an existing account to service account status, returning an access token"
  task :promote_to_service_account, [ :user_id ] => [ :environment ] do |_, args|
    user_id = args[:user_id]
    user = User.find(user_id)

    if user && user.update(is_service_account: true)
      token = user.api_access_tokens.create

      puts "User #{user_id} (#{user.email}) is now a service account: #{token.access_token}"
    end
  end

  # bin/rails 'users:demote_service_account[2]'
  desc "Demote an existing account, deleting all associated access tokens"
  task :demote_service_account, [ :user_id ] => [ :environment ] do |_, args|
    user_id = args[:user_id]
    user = User.find(user_id)

    if user && user.update(is_service_account: false)
      user.api_access_tokens.update_all(deleted_at: Time.now)

      puts "User #{user_id} (#{user.email}) is no longer a service account."
    end
  end
end
