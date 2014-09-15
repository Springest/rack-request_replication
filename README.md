# Rack::RequestReplication

Replicate requests from one app instance to another. At
[Springest](http://www.springest.com) we use this to test new features.
We replicate all live requests to our staging environment to test new
code before it goes live. With real traffic!

## Session support

It has support for sessions. To make use of it, you need to have Redis
running. Redis serves as a key-value store where sessions from the
Source App are linked to sessions from the Forward App. This way both
apps can have their own session management.

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
require 'sinatra/cookies'
require 'rack/request_replication'

class TestApp < Sinatra::Base
  # Forward all requests to another app that runs on localhost, port 4568
  use Rack::RequestReplication::Forwarder,
        host: 'localhost',
        port: 4568,
        session_key: 'rack.session',
        redis: {
          host: 'localhost',
          port: 6379,
          db: 'rack-request-replication'
        }

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
