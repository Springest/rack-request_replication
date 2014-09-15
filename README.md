# Rack::RequestReplication

Replicate requests from one app instance to another. At
[Springest](http://www.springest.com) we use this to test new features.
We replicate all live requests to our staging environment.

## Installation

Add this line to your application's Gemfile:

    gem 'rack-request_replication'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-request_replication

## Usage

### Sinatra Example

```ruby
require 'sinatra/base'
require 'rack/request_replication'

class TestApp < Sinatra::Base
  # Forward all requests to another app that runs on localhost, port 4568
  use Rack::RequestReplication::Forwarder, host: 'localhost', port: 4568

  get '/' do
    'Hello World'
  end
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/rack-request_replication/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
