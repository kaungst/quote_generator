require 'base64'
require 'openssl'
require 'json'
require 'rest-client'

class GdaxJsonClient
  def initialize(gdax_config)
    self.key = gdax_config[:key]
    self.secret = gdax_config[:secret]
    self.passphrase = gdax_config[:passphrase]
    self.api_base_url = gdax_config[:api_base_url]
  end

  def process_request(request_path: '', body: nil, query_params: {}, method: 'GET')
    headers = generate_headers(request_path, body, method)

    JSON.parse(
      RestClient::Request.execute(
        method: method,
        url: "#{api_base_url}/#{request_path}",
        headers: headers.merge(params: query_params),
        payload: body
      ).body
    )
  end

  private

  attr_accessor :key, :secret, :passphrase, :api_base_url

  def generate_signature(timestamp, request_path, body, method)
    formatted_body = "#{timestamp}#{method}#{request_path}#{body}";

    Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', Base64.decode64(secret), formatted_body)
    )
  end

  def generate_headers(request_path, body, method)
    timestamp = Time.now.to_i
    body = body.to_json unless body.nil?

    {
      'CB-ACCESS-KEY' => key,
      'CB-ACCESS-SIGN' => generate_signature(timestamp, request_path, body, method),
      'CB-ACCESS-TIMESTAMP' => timestamp,
      'CB-ACCESS-PASSPHRASE' => passphrase,
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
end
