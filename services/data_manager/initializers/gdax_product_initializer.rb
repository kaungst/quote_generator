require './initializers/base_initializer'

class GdaxProductInitializer < BaseInitializer
  def run
    products = app.external_clients.gdax_json_client.process_request(
      request_path: '/products'
    ).map(&:symbolize_keys)

    gdax_products = Hash.new { |h, k| h[k] = {} }
    gdax_product_ids = []

    products.each do |product|
      gdax_products[product[:base_currency]][product[:quote_currency]] = product
      gdax_product_ids << product[:id]
    end

    app.set :gdax_products, gdax_products
    app.set :gdax_product_ids, gdax_product_ids
  end
end
