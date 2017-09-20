require 'resque'
require './initializers/base_initializer'

class ResqueInitializer < BaseInitializer
  def run
    Resque.redis = app.external_clients.redis_client
  end
end
