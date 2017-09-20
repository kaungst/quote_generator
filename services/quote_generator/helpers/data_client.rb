require 'active_support/core_ext/hash/keys'

class DataClient
  def initialize(data_client_config)
    self.api_base_url = data_client_config[:api_base_url]
  end

  def product(base_currency, quote_currency, best: nil)
    product_id = generate_product_id(base_currency, quote_currency)
    url = "#{api_base_url}/products/#{product_id}/"
    url << "?best=#{best}" unless best.nil?

    JSON.parse(RestClient::Request.execute(method: 'GET', url: url).body).deep_symbolize_keys
  end

  def generate_product_id(base_currency, quote_currency)
    "#{base_currency}-#{quote_currency}"
  end

  private

  attr_accessor :api_base_url
end
