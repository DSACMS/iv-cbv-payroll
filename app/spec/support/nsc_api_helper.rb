module NscApiHelper
  def nsc_stub_request_education_search_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
      .to_return(
        status: 200,
        body: nsc_load_relative_json_file(user_folder, 'insight.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def nsc_fixture_path(user_folder, filename)
    File.join(File.dirname(__FILE__), "fixtures/nsc/#{user_folder}/#{filename}")
  end

  def nsc_load_relative_json_file(user_folder, filename)
    JSON.parse(File.read(nsc_fixture_path(user_folder, filename)))
  end
end
