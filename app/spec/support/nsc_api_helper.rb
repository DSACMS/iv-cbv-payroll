module NscApiHelper
  def nsc_stub_request_education_search_response(user_folder, &block)
    response_data = nsc_load_relative_json_file(user_folder, 'insight.json')
    block.call(response_data) if block_given?

    stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
      .to_return(
        status: 200,
        body: response_data.to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  # Stub a response where the OAuth token is expired.
  # Tests should expect that we request a new token and retry the education search.
  def nsc_stub_request_education_search_token_expired_response(user_folder)
    stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
      .to_return(
        { status: 401, body: "" },
        {
          status: 200,
          body: nsc_load_relative_json_file(user_folder, 'insight.json').to_json,
          headers: { 'Content-Type': 'application/json;charset=UTF-8' }
        }
      )
  end

  def nsc_stub_token_request
    stub_request(:post, %r{/token})
      .to_return(
        status: 200,
        body: JSON.generate(
          access_token: "this-is-a-fake-access-token-for-testing"
        )
      )
  end

  def nsc_fixture_path(user_folder, filename)
    File.join(File.dirname(__FILE__), "fixtures/nsc/#{user_folder}/#{filename}")
  end

  def nsc_load_relative_json_file(user_folder, filename)
    JSON.parse(File.read(nsc_fixture_path(user_folder, filename)))
  end

  # See this page for various NSC test cases:
  # https://docs.studentclearinghouse.org/vs/insights-json/integration-testing#test-cases-request
  #
  # To save a test case as a fixture, run these in a Rails console (replacing
  # the name and DOB with the values for the test case you want to save):
  #
  # ```
  # require_relative './spec/support/nsc_api_helper.rb'
  # include NscApiHelper
  # nsc_save_fixture_for_user("Johnson", "White", "1982-04-21")
  # ```
  def nsc_save_fixture_for_user(first_name, last_name, date_of_birth)
    fixture_file = nsc_fixture_path("#{first_name}_#{last_name}".downcase, "insight.json")
    FileUtils.mkdir_p(File.dirname(fixture_file))

    nsc_api = Aggregators::Sdk::NscService.new
    enrollment_data = nsc_api.fetch_enrollment_data(
      first_name: first_name,
      last_name: last_name,
      date_of_birth: date_of_birth
    )
    File.open(fixture_file, "w") do |f|
      f.puts JSON.pretty_generate(enrollment_data)
    end
  end
end
