require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "acts_as_tenant"

module Dummy
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    if Rails.gem_version < Gem::Version.new("6.0") && config.active_record.sqlite3
      config.active_record.sqlite3.represent_boolean_as_integer = true
    end
  end
end
