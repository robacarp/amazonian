require 'patron'
require 'crack'
require 'hashie'
require 'base64'

require 'amazonian/configuration'
require 'amazonian/item'
require 'amazonian/search'

#
# This module is designed to allow easier querying of the Amazon Product Advertising API
# from within your Ruby or Rails applications.
#
# Basic usage requires first calling +Amazonian.setup+ to provide your Amazon AWS Key and
# Secret key for the module to use in querying the database.
#
# Amazons internal product ids can be used to retrieve data from the API with +Amazonian.asin+.
#
# Searching for products is done via +Amazonian.search+
#
# @author Robert L. Carpenter (Modern codebase, interface, gem-ability)
# @author phoet (Original ASIN interface and implementation of Request Signing, etc.) https://github.com/phoet/asin
#
# @api Amazon Web Services Product Advertising API
#
# @version 0.3.0
#
module Amazonian
  class << self

    # An Amazonian configuration object. See Amazonian::Configuration.
    attr_accessor :configuration

    # Most recent request and response
    attr_reader :response, :request

    #
    # Configure the basic request parameters for Amazonian.
    #
    # Pass in a block with 1 parameter and modify configuration
    # variables from there.
    #
    # @yield Configuration code block.
    #
    # @example
    #     require 'Amazonian'
    #     Amazonian.setup do |config|
    #       config.key            = "my awesome key for AWS"
    #       config.secret         = "super secret secret key for AWS"
    #       config.debug          = true
    #       config.default_search = :Music
    #       config.cache_last     = false
    #     end
    #
    def setup
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    #
    # Perform an ASIN (Amazon Standard Identification Number) lookup.
    #
    # @param [String] The ASIN with which to query the API.
    # @param [Hash] Additional options to be passed to the API.
    # @option params [Symbol] :Operation defaults to :ItemLookup
    # @option params [Symbol] :ItemLookup defaults to the ASIN passed as param 1.
    #
    # @see For more information on the parameters the API accepts, see http://docs.amazonwebservices.com/AWSEcommerceService/4-0/
    #
    # @return [Amazonian::Item] Representing the response from the API
    #
    def asin(asin, params={})
      params = params.merge :Operation => :ItemLookup, :ItemId => asin
      xml    = call params
      Item.new xml['ItemLookupResponse']['Items']['Item']
    end

    #
    # Perform a search query to the API.  This is basically the same thing as
    # searching with the Amazon website.
    #
    # @param [String] The search query
    # @param [Hash] Additional options to be passed to the API
    # @option params [Symbol] :Operation defaults to :ItemSearch
    # @option params [Symbol] :Keywords defaults to the passed search query
    #
    # @see For more information on the parameters the API accepts, see http://docs.amazonwebservices.com/AWSEcommerceService/4-0/
    #
    # @return [Amazonian::Search] Representing the response from the API.  Items returned by the search query are represented as 
    #   +Amazonian::Item+ inside +Amazonian::Search+
    #
    def search(query, params={})
      params = params.merge :Operation => :ItemSearch,
                            :Keywords => query

      params[:SearchIndex] = configuration.default_search if params[:SearchIndex].nil?

      xml = call params
      Search.new xml['ItemSearchResponse']
    end

    private

    #
    # Director function. Builds out the Request, Signs it, Sends it off, and Parses its XML all via small helper functions.
    #
    # @param params [Hash] All of the parameters to be formatted into the API REST call.
    # @return [Crack::XML] The Parsed XML
    #
    def call(params)
      raise "Cannot call the Amazon API without key and secret key." \
        if configuration.key.blank? || configuration.secret.blank?

      debug = configuration.debug

      #get the signed query, and assemble the querystring
      log :debug, "Started Amazonian request for params: #{params.map {|p| "#{p[0]}=>#{p[1]}" }.join ','}" if debug

      #memoize the last request for faster API querying...
      query = assemble_querystring params
      if configuration.cache_last && query == @query && @response && @response.body
        log :debug, "MEMO'D! Shortcutting API call for dup request."
        return Crack::XML.parse @response.body
      end
      @query = query

      #sign the query
      signed = sign_query query

      #assemble the full URL
      @request = "http://#{configuration.host}#{configuration.path}?#{signed}"

      #make the call
      log :info, "performing rest call to '#{@request}'" if debug
      @response = patron.get @request

      log :debug, "Response Code: #{@response.status}" if debug

      #todo, this memo logic is broken....an error code is not always without a body
      log :error, "Amazon API Error: #{@response.status}" if @response.status >= 400

      #parse the response and return it
      Crack::XML.parse @response.body
    end

    #
    # Builds out a Query String from a hash of symbols.
    #
    def assemble_querystring(params)
      # Nice tutorial http://cloudcarpenters.com/blog/amazon_products_api_request_signing/
      params[:Service] = :AWSECommerceService
      params[:AWSAccessKeyId] = configuration.key

      # CGI escape each param
      # signing needs to order the query alphabetically
      params.map{|key, value| "#{key}=#{CGI.escape(value.to_s)}" }.sort.join('&').gsub('+','%20')
    end

    #
    # Signs a query string
    #
    def sign_query(query)
      #make a copy... fixme fixme I'm awkward
      q = query.clone
      # UTC timestamp needed for signing
      q <<= '&Timestamp=' << CGI.escape(Time.now.utc.strftime '%Y-%m-%dT%H:%M:%SZ')

      # Sign the entire get-request (not just the querystring)
      # possible gotcha if Patron starts using more/different headers.
      request_to_sign = "GET\n#{configuration.host}\n#{configuration.path}\n#{q}"

      "#{q}&Signature=#{sign_request request_to_sign}"
    end

    #
    # Signs an entire request string
    #
    def sign_request(request_to_sign)
      # Sign it.
      hmac = OpenSSL::HMAC.digest(digest, configuration.secret, request_to_sign)

      # Don't forget to remove the newline from base64
      CGI.escape(Base64.encode64(hmac).chomp)
    end

    def digest
      @digest ||= OpenSSL::Digest::Digest.new('sha256')
    end

    def patron
      if !@patron
        @patron = Patron::Session.new
        @patron.timeout = 10
      end
      @patron
    end

    def log(severity, message)
      logger = configuration.logger
      logger.send severity, message if logger
    end
  end

end
