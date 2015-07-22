require 'sinatra/base'
require 'sinatra/cookies'
require 'rack/request_replication'

$destination_responses ||= []

class TestApp < Sinatra::Base
  set :port, 4567

  enable :logging

  use Rack::RequestReplication::Forwarder, host: 'localhost',
        port: 4568,
        session_key: 'rack.session',
        redis: {
          host: 'localhost',
          port: 6379,
          db: 'rack-request-replication'
        }

  get '/' do
    'GET OK'
  end

  post '/' do
    request.params.to_s
  end

  put '/' do
    request.params.to_s
  end

  patch '/' do
    request.params.to_s
  end

  delete '/' do
    'DELETE OK'
  end

  options '/' do
    'OPTIONS OK'
  end
end

class DestApp < Sinatra::Base
  helpers Sinatra::Cookies

  set :port, 4568

  enable :logging

  before do
    cookies.merge! 'boo' => 'far', 'zar' => 'bab'
  end

  get '/' do
    $destination_responses << 'GET OK'
    'Hello, World!'
  end

  post '/' do
    $destination_responses << request.params.to_s
    'Created!'
  end

  put '/' do
    $destination_responses << request.params.to_s
    'Replaced!'
  end

  patch '/' do
    $destination_responses << request.params.to_s
    'Updated'
  end

  delete '/' do
    $destination_responses << 'DELETE OK'
    'Removed!'
  end

  options '/' do
    $destination_responses << 'OPTIONS OK'
    'Appeased!'
  end
end
