# Rakefile
require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('amazonian', '0.0.1') do |p|
  p.description    = "Building out ASIN to use the full Amazon Product Advertising API"
  p.url            = "http://robacarp.com"
  p.author         = "Robert Carpenter"
  p.email          = "robacarp@gmail.com"
  p.ignore_pattern = ["tmp/*", "script/*"]
  p.development_dependencies = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }

