# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "acts_as_tenant/version"

Gem::Specification.new do |s|
  s.name        = "acts_as_tenant"
  s.version     = ActsAsTenant::VERSION
  s.authors     = ["Erwin Matthijssen"]
  s.email       = ["erwin.matthijssen@gmail.com"]
  s.homepage    = "http://www.rollcallapp.com/blog"
  s.summary     = %q{Add multi-tenancy to Rails applications using a shared db strategy}
  s.description = %q{Integrates multi-tenancy into a Rails application in a convenient and out-of-your way manner}

  s.rubyforge_project = "acts_as_tenant"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  #add_runtime_dependency("rails")
  s.add_runtime_dependency('request_store', '>= 1.0.5')
  s.add_dependency('rails','>= 4.0.0.rc1')
  #s.add_dependency('request_store', '>= 1.0.5')

  s.add_development_dependency('rspec')
  s.add_development_dependency('database_cleaner')
  s.add_development_dependency('sqlite3')
  s.add_development_dependency('debugger')
end
