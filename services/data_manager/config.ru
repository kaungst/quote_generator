require 'eventmachine'
require 'thin'
require 'resque/server'
require File.expand_path('app', File.dirname(__FILE__))

EM.run do
  dispatch = Rack::Builder.app do
    map '/' do
      run App.new
    end
  end

  Rack::Server.start({
    app: dispatch,
    server: 'thin',
    Host: '0.0.0.0',
    Port: '8181',
    signals: false,
  })
end
