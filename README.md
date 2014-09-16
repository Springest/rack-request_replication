# Rack::RequestReplication - Replicate Rack app HTTP requests

Replicate requests from one app instance to another. At
[Springest](http://www.springest.com) we used
[Gor](https://github.com/buger/gor) once to test our new Postgres stack
vs our at that time current MySQL stack.
We replicated all live requests to our staging environment to test new
code before it went live. With real traffic!

Unfortunately, we could not test everything we wanted with the
[setup with Gor](http://devblog.springest.com/testing-big-infrastructure-changes-at-springest/).
Stuff that relied on sessions (like
[MySpringest](https://www.springest.com/my-springest), and course
management through our [Admin panel](http://providers.springest.com/))
could not be tested properly because the staging environment did not
share sessions with the production stack.

Recently, @foxycoder was asked to give a talk about these adventures at
[Amsterdam.rb](http://www.meetup.com/Amsterdam-rb/events/206133762/).
And while we were thinking about all the stuff that we needed to do to
get it right with Gor, we came up with the concept of this gem.

## Full control over the requests through Rack

This is Rack MiddleWare. And thanks to that, we have all the information
and handy tools available to parse and alter request data before we
forward it to another stack.


## Features

At the moment, it just forwards the request with only a couple of
changes:

- The host and/or port to match the stack to forward to.
- The session cookie – it stores a persistent link between the source
  app's session and the destination app's session in Redis.
- The CSRF token – same as the session, the destination app's
  `authenticity_token` is persistent and used in consecutive requests.

### Session support

It has support for sessions. To make use of it, you need to have Redis
running. Redis serves as a key-value store where sessions from the
Source App are linked to sessions from the Forward App. This way both
apps can have their own session management.

### Rails's CSRF tokens

Rails uses a cross site scripting defense mechanism in the form of an
`authenticity_token` parameter. Absense of it, or modifying it between
requests results in XSS errors. Therefore we needed to make sure these
were properly captured and replaced by the Forwarder before sending the
request to the other application.

CSRF tokens are also persisted in Redis and used in consecutive requests, by
updating `params["authenticity_token"]` before handing off the request
to the replica app.

## API Docs

Check out the official [API docs](http://rubydoc.info/gems/rack-request_replication)

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
