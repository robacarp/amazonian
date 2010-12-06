require 'patron'
require 'crack'
require 'hashie'

module Amazonian
  #worker objects
  @@digest = OpenSSL::Digest::Digest.new('sha256')
  @@logger = Logger.new(STDERR)
  @@patron = Patron::Session.new

  #hold the most recent request/response
  @@request  = nil
  @@response = nil
  @@query    = nil

  #configuration variables
  @@host           = 'webservices.amazon.com'
  @@path           = '/onca/xml'
  @@debug          = true
  @@key            = ''
  @@secret         = ''
  @@default_search = :All
  @@cache_last     = true

  mattr_reader   :host,:path,:response,:request
  mattr_accessor :key,:secret,:debug,:default_search,:cache_last

  #Configure Patron
  @@patron.timeout = 10

  # Configure the basic request parameters for Amazonian.
  def self.setup
    yield self if block_given?
  end

  def self.asin(asin, params={})
    params = params.merge :Operation => :ItemLookup, :ItemId => asin
    xml    = self.call params
    Item.new xml['ItemLookupResponse']['Items']['Item']
  end

  def self.search(query, params={})
    params = params.merge :Operation => :ItemSearch,
                          :Keywords => query

    params[:SearchIndex] = @@default_search if params[:SearchIndex].nil?

    xml = self.call params
    Search.new xml['ItemSearchResponse']
  end

  private

  def self.call(params)
    raise "Cannot call the Amazon API without key and secret key." if @@key.blank? || @@secret.blank?

    #get the signed query, and assemble the querystring
    log :debug, "Started Amazonian request for params: #{params.map {|p| "#{p[0]}=>#{p[1]}" }.join ','}"  if @@debug

    #memoize the last request for faster API querying...
    query = assemble_querystring params
    if @@cache_last && query == @@query && @@response.body
      log :debug, "MEMO'D! Shortcutting API call for dup request."
      return Crack::XML.parse @@response.body
    end
    @@query = query

    #sign the query
    signed = sign_query query

    #assemble the full URL
    @@request = "http://#{@@host}#{@@path}?#{signed}"

    #make the call
    log :info, "performing rest call to '#{@@request}'" if @@debug
    @@response = @@patron.get @@request

    log :debug, "Response Code: #{@@response.status}" if @@debug

    #todo, this memo logic is broken....an error code is not always without a body
    log :error, "Amazon API Error: #{@@response.status}" if @@response.status >= 400

    #parse the response and return it
    Crack::XML.parse @@response.body
  end

  def self.assemble_querystring(params)
    # Nice tutorial http://cloudcarpenters.com/blog/amazon_products_api_request_signing/
    params[:Service] = :AWSECommerceService
    params[:AWSAccessKeyId] = @@key

    # CGI escape each param
    # signing needs to order the query alphabetically
    params.map{|key, value| "#{key}=#{CGI.escape(value.to_s)}" }.sort.join('&').gsub('+','%20')
  end

  def self.sign_query(query)
    #make a copy... fixme fixme I'm awkward
    q = query.clone
    # UTC timestamp needed for signing
    q <<= '&Timestamp=' << CGI.escape(Time.now.utc.strftime '%Y-%m-%dT%H:%M:%SZ')

    # Sign the entire get-request (not just the querystring)
    # possible gotcha if Patron starts using more/different headers.
    request_to_sign = "GET\n#{@@host}\n#{@@path}\n#{q}"

    "#{q}&Signature=#{sign_request request_to_sign}"
  end

  def self.sign_request(request_to_sign)
    # Sign it.
    hmac = OpenSSL::HMAC.digest(@@digest, @@secret, request_to_sign)

    # Don't forget to remove the newline from base64
    CGI.escape(Base64.encode64(hmac).chomp)
  end

  def self.log(severity, message)
    @@logger.send severity, message if @@logger
  end


  # =Item
  #
  # The +Item+ class is a wrapper for the Amazon XML-REST-Response.
  #
  # A Hashie::Mash is used for the internal data representation and can be accessed over the +raw+ attribute.
  #
  class Item
    attr_reader :raw
    def initialize(hash)
      @raw = Hashie::Mash.new(hash)
    end

    def title
      if @raw.ItemAttributes && @raw.ItemAttributes.Title
        @raw.ItemAttributes.Title
      else
        nil
      end
    end
  end

  class Search
    attr_reader :items
    def initialize(hash)
      @raw = Hashie::Mash.new(hash)
      @items = []

      if @raw.Items && @raw.Items.Item
        if @raw.Items.TotalResults.to_i > 1
          @raw.Items.Item.each {|i| @items.push Amazonian::Item.new(i) }
        else
          @items.push Amazonian::Item.new(@raw.Items.Item)
        end
      end
    end
  end

end
