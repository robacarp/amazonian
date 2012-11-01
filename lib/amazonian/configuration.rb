require 'logger'

module Amazonian
  class Configuration

    # Amazon Web Service hostname
    attr_accessor :host

    # Amazon Web Service path
    attr_accessor :path

    # Amazon Web Service key
    attr_accessor :key

    # Amazon Web Service secret
    attr_accessor :secret

    # Turn debugging on
    attr_accessor :debug

    # The default search filter (defaults to :All)
    # Other tempting options: :Music, :GourmetFood, etc
    attr_accessor :default_search

    # Attempt to filter out duplicate requests
    attr_accessor :cache_last

    attr_accessor :logger

    def initialize
      @host           = 'webservices.amazon.com'
      @path           = '/onca/xml'
      @debug          = false
      @key            = ''
      @secret         = ''
      @default_search = :All
      @cache_last     = true
      @logger         = Logger.new(STDERR)
    end

  end
end
