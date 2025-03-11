module ArgyleApiHelper
  def stub_request_items_response(userFolder)
    stub_request(:get, %r{#{ArgyleService::ITEMS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(userFolder, 'request_items.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_paystubs_response(userFolder)
    stub_request(:get, %r{#{ArgyleService::PAYSTUBS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(userFolder, 'request_paystubs.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_gigs_response(userFolder)
    stub_request(:get, %r{#{ArgyleService::GIGS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(userFolder, 'request_gigs.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_identities_response(userFolder)
    stub_request(:get, %r{#{ArgyleService::IDENTITIES_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(userFolder, 'request_identity.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end


  def load_relative_file(userFolder, filename)
    File.read(File.join(
      File.dirname(__FILE__),
      "fixtures/argyle/#{userFolder}/#{filename}"
    ))
  end

  def load_relative_json_file(userFolder, filename)
    JSON.parse(load_relative_file(userFolder, filename))
  end
end
