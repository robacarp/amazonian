module Amazonian
  @@host   = 'webservices.amazon.com'
  @@path   = '/onca/xml'
  @@digest = OpenSSL::Digest::Digest.new('sha256')
  @@logger = Logger.new(STDERR)
  @@patron = Patron::Session.new
  @@last_response = nil
  @@key    = ''
  @@secret = ''
  @@debug  = false

  mattr_reader   :host,:path,:digest,:patron,:last_response
  mattr_accessor :key,:secret,:debug

  #Configure the patron session
  @@patron.timeout = 10

  # Configure the basic request parameters for Amazonian.
  def self.setup
    yield self if block_given?
  end

  # Performs an +ItemLookup+ REST call against the Amazon API.
  #
  # Expects an ASIN (Amazon Standard Identification Number) and returns an +Item+:
  #
  #   item = lookup '1430218150'
  #   item.title
  #   => "Learn Objective-C on the Mac (Learn Series)"
  #
  # ==== Options:
  #
  # Additional parameters for the API call like this:
  #
  #   lookup(asin, :ResponseGroup => :Medium)
  #
  def self.asin(asin, params={})
    params = params.merge :Operation => :ItemLookup, :ItemId => asin
    xml    = self.call params
    Item.new xml
  end

  private

  def self.call(params)
    raise "you have to configure ASIN: 'configure :secret => 'your-secret', :key => 'your-key''" if @@key.nil? || @@secret.nil?

    #get the signed query, and assemble the querystring
    log :debug, "calling with params=#{params}"  if @@debug
    signed = assemble_querystring params
    url = "http://#{@@host}#{@@path}?#{signed}"

    log :info, "performing rest call to url='#{url}'" if @@debug
    @@last_response = @@patron.get url

    # force utf-8 chars, works only on 1.9 string
    log :debug, "got response='#{@@last_response}'" if @@debug

    #parse the response and return it
    return @@last_response
    Crack::XML.parse @@last_response.body
  end

  def self.assemble_querystring(params)
    # Nice tutorial http://cloudcarpenters.com/blog/amazon_products_api_request_signing/
    params[:Service] = :AWSECommerceService
    params[:AWSAccessKeyId] = @@key

    # UTC timestamp needed for signing
    params[:Timestamp] = Time.now.utc.strftime '%Y-%m-%dT%H:%M:%SZ'

    # CGI escape each param
    # signing needs to order the query alphabetically
    query = params.map{|key, value| "#{key}=#{CGI.escape(value.to_s)}" }.sort.join('&')

    sign_query query
  end

  def self.sign_query(query)
    # Sign the entire get-request (not just the querystring)
    # possible gotcha if Patron starts using more/different headers.
    request_to_sign = %Q{GET\n#{@@host}\n#{@@path}\n#{query}}

    # Sign it.
    hmac = OpenSSL::HMAC.digest(@@digest, @@secret, request_to_sign)

    # Don't forget to remove the newline from base64
    signature = CGI.escape(Base64.encode64(hmac).chomp)

    "#{query}&Signature=#{signature}"
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
      @raw = Hashie::Mash.new(hash).ItemLookupResponse.Items.Item
    end

    def title
      @raw.ItemAttributes.Title
    end

  end
end
