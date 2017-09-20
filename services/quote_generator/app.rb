require 'json'
require 'rest-client'
require 'sinatra/base'
require 'sinatra/config_file'
require './helpers/data_client'
require './helpers/quote_generator'

class App < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  configure do
    set :data_client, DataClient.new(settings.data_client)
    set :quote_generator, QuoteGenerator.new(data_client)
  end

  before do
    content_type :json
  end

  get '/' do
    settings.data_client.product('USD', 'BTC').to_json
  end

  post '/quote' do
    data = JSON.parse(request.body.read).symbolize_keys
    settings.quote_generator.quote(**data).to_json
  end
end
