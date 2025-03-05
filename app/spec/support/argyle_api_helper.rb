module ArgyleApiHelper
  def stub_request_items_response 
    stub_request(:get,%r{#{ArgyleService::ITEMS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_items.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

 def load_relative_file(filename)
    File.read(File.join(
      File.dirname(__FILE__),
      "fixtures/argyle/#{filename}"
    ))
  end

  def load_relative_json_file(filename)
    JSON.parse(load_relative_file(filename))
  end
end