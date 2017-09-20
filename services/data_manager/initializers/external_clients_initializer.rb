require 'redis'
require './initializers/base_initializer'
require './helpers/gdax_json_client'

class ExternalClientsInitializer < BaseInitializer
  ExternalClientsStruct = Struct.new(:gdax_json_client, :redis_client)

  def run
    external_clients = ExternalClientsStruct.new(
      GdaxJsonClient.new(app.settings.gdax),
      Redis.new
    )

    app.set :external_clients, external_clients
  end
end
