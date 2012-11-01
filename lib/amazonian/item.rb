module Amazonian
  # =Item
  #
  # The +Item+ class is used to neatly box up the Amazon REST API responses into an Object.
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
end
