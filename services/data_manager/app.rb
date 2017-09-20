require 'bigdecimal'
require 'json'
require 'redis'
require 'sinatra/base'
require 'sinatra/config_file'
require './helpers/gdax_json_client'
require './helpers/gdax_data_parsers'
require './initializers/external_clients_initializer'
require './initializers/resque_initializer'
require './initializers/gdax_product_initializer'
require './initializers/gdax_webhook_initializer'

class App < Sinatra::Base
  include GdaxDataParsers

  register Sinatra::ConfigFile

  config_file './config/config.yml'

  def self.initialize_gdax_settings
    [GdaxProductInitializer, GdaxWebhookInitializer].each do |initializer|
      initializer.new(app: self).run
    end
  end

  configure do
    ExternalClientsInitializer.new(app: self).run
    ResqueInitializer.new(app: self).run
    initialize_gdax_settings
  end

  before do
    content_type :json
  end

  get '/products/:product_id/' do
    base, quote = parse_product_id(params[:product_id])

    unless settings.gdax_products.has_key?(base)
      quote, base = [base, quote]
    end

    if params[:best].to_i == 50
      product_id = generate_product_id(base, quote)
      order_book = settings.external_clients.gdax_json_client.process_request(
        request_path: "/products/#{product_id}/book?level=2"
      )

      settings.gdax_products[base][quote].merge(order_book: order_book).to_json
    else
      order_book = settings.gdax_products[base][quote][:order_book].dup

      order_book[:bids] = order_book[:bids].map { |k, v| [k, v, 1] }
      order_book[:bids].sort_by! { |a| [BigDecimal.new(a[0]), BigDecimal.new(a[1])] }
      order_book[:asks] = order_book[:asks].map { |k, v| [k, v, 1] }
      order_book[:asks].sort_by! { |a| [BigDecimal.new(a[0]), BigDecimal.new(a[1])] }
        
      settings.gdax_products[base][quote].merge(order_book: order_book).to_json
    end
  end
end
