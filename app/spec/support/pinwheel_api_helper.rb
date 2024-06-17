module PinwheelApiHelper
  stub_request(:get, /#{PinwheelService::PAYSTUBS_ENDPOINT}/).
  end
  with(
    headers: {
      'Accept'=>'*/*',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization'=>'Basic foobar',
      'Content-Type'=>'application/json',
      'User-Agent'=>'Faraday v2.9.0'
    }).
  to_return(status: 200, body: "", headers: {})
end