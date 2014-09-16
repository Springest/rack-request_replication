require 'logger'
require 'json'
require 'net/http'
require 'uri'
require 'redis'

module Rack
  module RequestReplication
    ##
    # This class implements forwarding of requests
    # to another host and/or port.
    #
    class Forwarder
      attr_reader :app
      attr_reader :options

      ##
      # @param  [#call]                  app
      # @param  [Hash{Symbol => Object}] options
      # @option options [String]                 :host  ('localhost')
      # @option options [Integer]                :port  (8080)
      # @option options [String]                 :session_key ('rack.session')
      # @option options [Hash{Symbol => Object}] :redis
      #   @option redis [String]  :host ('localhost')
      #   @option redis [Integer] :port (6379)
      #   @option redis [String]  :db   ('rack-request-replication')
      #
      def initialize( app, options = {} )
        @app = app
        @options = {
          host: 'localhost',
          port: 8080,
          session_key: 'rack.session',
          root_url: '/',
          redis: {}
        }.merge options
      end

      ##
      # @param  [Hash{String => String}] env
      # @return [Array(Integer, Hash, #each)]
      # @see    http://rack.rubyforge.org/doc/SPEC.html
      #
      def call( env )
        request = Rack::Request.new env
        replicate request
        app.call env
      end

      ##
      # Replicates the request and passes it on to the request
      # forwarder.
      #
      # @param  [Rack::Request] request
      #
      def replicate( request )
        opts = replicate_options_and_data request
        uri = forward_uri request

        http = Net::HTTP.new uri.host, uri.port

        forward_request = send("create_#{opts[:request_method].downcase}_request", uri, opts)
        forward_request.add_field("Accept", opts[:accept])
        forward_request.add_field("Accept-Encoding", opts[:accept_encoding])
        forward_request.add_field("Host", request.host)

        Thread.new do
          begin
            forward_request.add_field("Cookie", cookies( request ))
            update_csrf_token_and_cookies( request, http.request(forward_request) )
          rescue => e
            logger.debug "Replicating request failed with: #{e.message}"
          end
        end
      end

      ##
      # Update CSRF token and cookies.
      #
      # @param   [Rack::Request] request
      # @param   [Net::HTTP::Response] response
      #
      def update_csrf_token_and_cookies( request, response )
        update_csrf_token( request, response )
        update_cookies( request, response )
      end

      ##
      # The CSRF-token to use.
      #
      # @param   [Rack::Request] request
      # @returns [String]
      #
      def csrf_token( request )
        token = request.params["authenticity_token"]
        return if token.nil?

        redis.get( "csrf-#{token}" ) || token
      end

      ##
      # Update CSRF token to bypass XSS errors in Rails.
      #
      # @param   [Rack::Request] request
      #
      def update_csrf_token( request, response )
        token = request.params["authenticity_token"]
        return if token.nil?

        response_token = csrf_token_from response
        return token if response_token.nil?

        redis.set "csrf-#{token}", response_token
      end

      ##
      # Pull CSRF token from the HTML document's header.
      #
      # @param   [Net::HTTP::Response] response
      # @returns [String]
      #
      def csrf_token_from( response )
        response.split("\n").
          select{|l| l.match(/csrf-token/) }.
          first.split(" ").
          select{|t| t.match(/^content=/)}.first.
          match(/content="(.*)"/)[1]
      rescue
        nil
      end

      ##
      # Update cookies from the forwarded request using the session id
      # from the cookie of the source app as a key. The cookie is stored
      # in Redis.
      #
      # @param [Rack::Request] request
      # @param [Net::HTTP::Response] response
      #
      def update_cookies( request, response )
        return unless cookies_id( request )
        cookie = response.to_hash['set-cookie'].collect{|ea|ea[/^.*?;/]}.join rescue {}
        cookie = Hash[cookie.split(";").map{|d|d.split('=')}] rescue {}
        redis.set( cookies_id( request), cookie )
      end

      ##
      # Cookies Hash to use for the forwarded request.
      #
      # Tries to find the cookies from earlier forwarded
      # requests in the Redis store, otherwise falls back
      # to the cookies from the source app.
      #
      # @param   [Rack::Request] request
      # @returns [Hash]
      #
      def cookies( request )
        return ( request.cookies || "" ) unless cookies_id( request )
        redis.get( cookies_id( request )) ||
          request.cookies ||
          {}
      end

      ##
      # The key to use when looking up cookie stores in
      # Redis for forwarding requests. Needed for session
      # persistence over forwarded requests for the same
      # user in the source app.
      #
      # @param   [Rack::Request] request
      # @returns [String]
      #
      def cookies_id( request )
        cs = request.cookies
        sess = cs && cs[options[:session_key]]
        sess_id = sess && sess.split("\n--").last
        sess_id
      end

      ##
      # Prepare a GET request to the forward app.
      #
      # The passed in options hash is ignored.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Get]
      #
      def create_get_request( uri, opts = {} )
        Net::HTTP::Get.new uri.request_uri
      end

      ##
      # Prepare a POST request to the forward app.
      #
      # The passed in options hash contains all the
      # data from the request that needs to be forwarded.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Post]
      #
      def create_post_request( uri, opts = {} )
        forward_request = Net::HTTP::Post.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      ##
      # Prepare a PUT request to the forward app.
      #
      # The passed in options hash contains all the
      # data from the request that needs to be forwarded.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Put]
      #
      def create_put_request( uri, opts = {} )
        forward_request = Net::HTTP::Put.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      ##
      # Prepare a PATCH request to the forward app.
      #
      # The passed in options hash contains all the
      # data from the request that needs to be forwarded.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Patch]
      #
      def create_patch_request( uri, opts = {} )
        forward_request = Net::HTTP::Patch.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      ##
      # Prepare a DELETE request to the forward app.
      #
      # The passed in options hash is ignored.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Delete]
      #
      def create_delete_request( uri, opts = {} )
        Net::HTTP::Delete.new uri.request_uri
      end

      ##
      # Prepare a OPTIONS request to the forward app.
      #
      # The passed in options hash is ignored.
      #
      # @param   [URI] uri
      # @param   [Hash{Symbol => Object}] opts ({})
      # @returns [Net:HTTP::Options]
      #
      def create_options_request( uri, opts = {} )
        Net::HTTP::Options.new uri.request_uri
      end

      ##
      # Replicates all the options and data that was in
      # the original request and puts them in a Hash.
      #
      # @param   [Rack::Request] request
      # @returns [Hash]
      #
      def replicate_options_and_data( request )
        replicated_options ||= {}
        %w(
          accept_encoding
          body
          request_method
          content_charset
          media_type
          media_type_params
          params
          referer
          request_method
          user_agent
          url
        ).map(&:to_sym).each do |m|
          value = request.send( m )
          replicated_options[m] = value unless value.nil?
        end

        if replicated_options[:params]["authenticity_token"]
          replicated_options[:params]["authenticity_token"] = csrf_token
        end

        replicated_options
      end

      ##
      # Creates a URI based on the request info
      # and the options set.
      #
      # @param   [Rack::Request] request
      # @returns [URI]
      #
      def forward_uri( request )
        url = "#{request.scheme}://#{forward_host_with_port( request )}"
        url << request.fullpath
        URI(url)
      end

      ##
      # The host to forward to including the port if
      # the port does not match the current scheme.
      #
      # @param   [Rack::Request] request
      # @returns [String]
      #
      def forward_host_with_port( request )
        host = options[:host].to_s
        host = "#{host}:#{options[:port]}" unless port_matches_scheme? request
        host
      end

      ##
      # Persistent Redis connection that is used
      # to store cookies.
      #
      def redis
        @redis ||= Redis.new({
          host: 'localhost',
          port: 6379,
          db: 'rack-request-replication'
        }.merge(options[:redis]))
      end

      ##
      # Checks if the request scheme matches the destination port.
      #
      # @param   [Rack::Request] request
      # @returns [boolean]
      #
      def port_matches_scheme?( request )
        options[:port].to_i == Rack::Request::DEFAULT_PORTS[clean_scheme(request)]
      end

      ##
      # Request scheme without the ://
      #
      # @param   [Rack::Request] request
      # @returns [String]
      #
      def clean_scheme( request )
        request.scheme.match(/^\w+/)[0]
      end

      ##
      # Logger that logs to STDOUT
      #
      # @returns [Logger]
      #
      def logger
        @logger ||= ::Logger.new(STDOUT)
      end
    end
  end
end
