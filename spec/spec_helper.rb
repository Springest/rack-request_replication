require 'rspec'
require 'rack/test'
require 'rack/request_replication'

ENV['RACK_ENV'] ||= 'test'

require File.expand_path('../app/test_app.rb', __FILE__)

RSpec.configure do |config|
  config.before :suite do
    puts "Starting example applications on ports 4567 (source) and 4568 (destination)."
    @dpid = Thread.new { DestApp.run! }
    sleep 1
  end

  config.after :suite do
    puts "Quitting example applications..."
    @dpid.kill
  end
end
