require 'logger'
require 'json'
require 'net/http'
require 'uri'

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
      # @option options [String]  :host  ('localhost')
      # @option options [Integer] :port  (8080)
      # @option options [String]  :session_key ('rack.session')
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
        forward_request.add_field("Cookie", opts[:cookies]) # TODO: we need to link the source session to the session on the destination app. Maybe we can use Redis to store this.
        Thread.new do
          begin
            http.request(forward_request)
          rescue
            logger.debug "Request to Forward App failed."
          end
        end
      end

      def create_get_request( uri, opts = {} )
        Net::HTTP::Get.new uri.request_uri
      end

      def create_post_request( uri, opts = {} )
        forward_request = Net::HTTP::Post.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      def create_put_request( uri, opts = {} )
        forward_request = Net::HTTP::Put.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      def create_patch_request( uri, opts = {} )
        forward_request = Net::HTTP::Patch.new uri.request_uri
        forward_request.set_form_data opts[:params]
        forward_request
      end

      def create_delete_request( uri, opts = {} )
        Net::HTTP::Delete.new uri.request_uri
      end

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
          cookies
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

      def forward_host_with_port( request )
        host = options[:host].to_s
        host << ":#{options[:port]}" unless port_matches_scheme? request
      end

      ##
      # Persistent Redis connection that is used
      # to store cookies.
      #
      def redis
        @redis ||= Redis.new({
          host: 'localhost',
          port: 6380,
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

      def clean_scheme( request )
        request.scheme.match(/^\w+/)[0]
      end

      def logger
        @logger ||= ::Logger.new(STDOUT)
      end
    end
  end
end
