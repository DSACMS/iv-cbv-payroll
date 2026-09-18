module NscApiHelper
  # See this page for various NSC test cases:
  # https://docs.studentclearinghouse.org/vs/insights-json/integration-testing#test-cases-request
  #
  # Each as_of_date is chosen to pin the persona's currentEnrollmentStatus:
  # a date within the persona's enrollment yields "CC", a later one yields "CN".
  FIXTURE_PERSONAS = {
    "lynette" => { first_name: "Lynette", last_name: "Oyola", date_of_birth: "1988-10-24", as_of_date: "2024-11-19" },
    "rick_banas" => { first_name: "Rick", last_name: "Banas", date_of_birth: "1979-08-18", as_of_date: "2024-11-29" },
    "dominique_ricardo" => { first_name: "Dominique", last_name: "Ricardo", date_of_birth: "1978-01-12", as_of_date: "2024-05-09" },
    "linda" => { first_name: "Linda", last_name: "Cooper", date_of_birth: "1999-01-01", as_of_date: "2024-11-19" },
    "scott_tobin" => { first_name: "Scott", last_name: "Tobin", date_of_birth: "1998-02-03", as_of_date: "2026-07-31" }
  }.freeze

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

  # Re-record every fixture against the live NSC sandbox, from the repo root:
  #
  # ```
  # cd app && bin/rails runner 'require "./spec/support/nsc_api_helper"; include NscApiHelper; nsc_save_all_fixtures'
  # ```
  def nsc_save_all_fixtures
    FIXTURE_PERSONAS.each_key { |user_folder| nsc_save_fixture_for_user(user_folder) }
  end

  def nsc_save_fixture_for_user(user_folder)
    persona = FIXTURE_PERSONAS.fetch(user_folder)
    fixture_file = nsc_fixture_path(user_folder, "insight.json")
    FileUtils.mkdir_p(File.dirname(fixture_file))

    enrollment_data = Aggregators::Sdk::NscService.new.fetch_enrollment_data(**persona)
    File.open(fixture_file, "w") do |f|
      f.puts JSON.pretty_generate(enrollment_data)
    end
  end
end
