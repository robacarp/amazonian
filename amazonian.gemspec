# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "amazonian/version"

Gem::Specification.new do |s|
  s.name        = "amazonian"
  s.version     = Amazonian::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Robert L. Carpenter"]
  s.email       = ["robacarp@robacarp.com"]
  s.homepage    = ""
  s.summary     = %q{Easy to use ruby module for the Amazon Product Advertising API}
  s.description = %q{Easy to use ruby module for the Amazon Product Advertising API}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"

  s.add_dependency "hashie"
  s.add_dependency "crack"
  s.add_dependency "patron"
  #s.add_dependency "httpclient"
  #s.add_dependency "crack/xml"
  #included in ruby?
  #s.add_dependency "cgi"
  #um
  #s.add_dependency "Base64"
  #s.add_dependency "logger"
end
