require 'addressable/uri'

module Trello
  # Client is used to handle the OAuth connection to Trello as well as send requests over that authenticated socket.
  class Client
    class EnterYourPublicKey < StandardError; end
    class EnterYourSecret < StandardError; end

    class << self
      attr_writer :public_key, :secret

      # call-seq:
      #   get(path, params)
      #   post(path, params)
      #   put(path, params)
      #   delete(path, params)
      #   query(api_version, path, options)
      #
      # Makes a query to a specific path via one of the four HTTP methods, optionally
      # with a hash specifying parameters to pass to Trello.
      #
      # You should use one of _.get_, _.post_, _.put_ or _.delete_ instead of this method.
      def query(api_version, path, options = { :method => :get, :params => {} })
        uri = Addressable::URI.parse("https://api.trello.com/#{api_version}#{path}")
        uri.query_values = options[:params]

        response = access_token.send(options[:method], uri.to_s)
        raise Error, response.message if response.code.to_i != 200
        response
      rescue OAuth::Problem => e
        headers = []
        e.request.each_header do |k,v|
          headers << [k, v]
        end

        logger.error("[#{@access_token}] Disposing of access token.\n#{e.inspect}")
        @access_token = nil
      end

      %w{get post put delete}.each do |http_method|
        send(:define_method, http_method) do |*args|
          path = args[0]
          params = args[1] || {}
          query(API_VERSION, path, :method => http_method, :params => params).read_body
        end
      end

      protected

      def consumer
        raise EnterYourPublicKey if @public_key.to_s.empty?
        raise EnterYourSecret if @secret.to_s.empty?

        OAuth::Consumer.new(@public_key, @secret, :site               => 'http://trello.com',
                                                  :request_token_path => '/1/OAuthGetRequestToken',
                                                  :authorize_path     => '/1/OAuthAuthorizeToken',
                                                  :access_token_path  => '/1/OAuthGetAccessToken',
                                                  :context            => 'read,write',
                                                  :http_method        => :get)
      end

      def access_token
        return @access_token if @access_token

        @access_token = OAuth::AccessToken.new(consumer)
      end
    end
  end
end
