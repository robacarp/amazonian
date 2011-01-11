module Amazonian
  # =Search
  # The +Search+ class is used to neatly box up the Amazon REST API responses into Objects.
  #
  # When using Amazonian.search you should receive an Search object.  Search also attempts
  # to autoboxe all of the Items returned in the search results into an array of +Amazonian::Item+
  # objects.
  #
  # A Hashie::Mash is used for the internal data representation and can be accessed over the +raw+ attribute.
  #
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
