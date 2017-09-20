require 'json'
require 'active_support/core_ext/hash/keys'
require 'faye/websocket'
require './initializers/base_initializer'
require './jobs/process_gdax_l2_update'
require './helpers/gdax_data_parsers'

class GdaxWebhookInitializer < BaseInitializer
  include GdaxDataParsers

  def run
    EM.next_tick {
      ws = Faye::WebSocket::Client.new(app.settings.gdax[:websocket_url])

      ws.on :open do |event|
        app.external_clients.redis_client.set('yolo', Time.now.to_s)
        ws.send(
          {
            type: 'subscribe',
            product_ids: app.gdax_product_ids,
            channels: ['level2']
          }.to_json
        )
      end

      ws.on :message do |event|
        event_data = JSON.parse(event.data).symbolize_keys

        case event_data[:type]
        when 'snapshot'
          base, quote = parse_product_id(event_data[:product_id])

          app.gdax_products[base][quote][:order_book] = {
            bids: event_data[:bids].to_h, asks: event_data[:asks].to_h
          }
        when 'l2update'
          base, quote = parse_product_id(event_data[:product_id])

          product = app.gdax_products[base][quote]

          event_data[:changes].each do |change|
            side, price, size = change

            side = side.to_sym == :buy ? :bids : :asks

            if size.to_f.zero?
              product[:order_book][side].delete(price)
            else
              product[:order_book][side][price] = size
            end
          end
        end
      end

      ws.on :close do |event|
        p [:close, event.code, event.reason]
        ws = nil
      end
    }
  end
end
