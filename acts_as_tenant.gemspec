$:.push File.expand_path("../lib", __FILE__)
require "acts_as_tenant/version"

Gem::Specification.new do |spec|
  spec.name = "acts_as_tenant"
  spec.version = ActsAsTenant::VERSION
  spec.authors = ["Erwin Matthijssen", "Chris Oliver"]
  spec.email = ["erwin.matthijssen@gmail.com", "excid3@gmail.com"]
  spec.homepage = "https://github.com/ErwinM/acts_as_tenant"
  spec.summary = "Add multi-tenancy to Rails applications using a shared db strategy"
  spec.description = "Integrates multi-tenancy into a Rails application in a convenient and out-of-your way manner"
  spec.metadata = { "rubygems_mfa_required" => "true" }

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0"
end
