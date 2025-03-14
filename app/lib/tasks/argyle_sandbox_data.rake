namespace :argyle_sandbox_data do
  desc "Fetch and store argyle fixture data."
  task :fetch, [ :mock_folder_name, :argyle_user_id ] => :environment do |t, args|
    if not (args.key?(:mock_folder_name) and args.key?(:argyle_user_id))
      puts "Must pass [:mock_folder_name, :arglye_user_id] as args to rake task"
    elsif not (ENV.key?("ARGYLE_SANDBOX") and ENV["ARGYLE_SANDBOX"])
      puts "ARGYLE_SANDBOX must be set to 'true' in .env"
    else
      puts ":mock_folder_name was: '#{args[:mock_folder_name]}'"
      puts ":argyle_user_id was: '#{args[:argyle_user_id]}'"
      a = ArgyleMockDataFetcher.new
      a.fetch_and_store_mock_data_for_user(mock_folder_name: args[:mock_folder_name], argyle_user_id: args[:argyle_user_id])
    end
  end

  class ArgyleMockDataFetcher
    def initialize
      @argyle = ArgyleService.new("sandbox")
    end

    def store_mock_response(response_payload:, folder_name: "other", file_name:)
      FileUtils.mkdir_p "spec/support/fixtures/argyle/#{folder_name}"

      out_file = "spec/support/fixtures/argyle/#{folder_name}/#{file_name}.json"
      File.open(out_file, "wb") do |f|
        f.puts(JSON.pretty_generate(response_payload))
        puts("File written at #{out_file}")
      end
    end

    # Only for use in sandbox environment for test mocking
    def fetch_and_store_mock_data_for_user(mock_folder_name:, argyle_user_id:)
      store_mock_response(
        folder_name: mock_folder_name,
        file_name: "request_user",
        response_payload: @argyle.fetch_user_api(user: argyle_user_id))

      store_mock_response(
        folder_name: mock_folder_name,
        file_name: "request_identity",
        response_payload: @argyle.fetch_identities_api(user: argyle_user_id))

      store_mock_response(
        folder_name: mock_folder_name,
        file_name: "request_employment",
        response_payload: @argyle.fetch_employments_api(user: argyle_user_id))

      store_mock_response(
        folder_name: mock_folder_name,
        file_name: "request_accounts",
        response_payload: @argyle.fetch_accounts_api(user: argyle_user_id))

      store_mock_response(
        folder_name: mock_folder_name,
        file_name: "request_paystubs",
        response_payload: @argyle.fetch_paystubs_api(user: argyle_user_id))
    end
  end
end
