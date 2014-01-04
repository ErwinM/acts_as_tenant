$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'database_cleaner'
require 'acts_as_tenant'
require 'rspec/rails'
require 'rails'

config = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite'])

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    ActsAsTenant.current_tenant = nil
  end
  
  config.infer_base_class_for_anonymous_controllers = true
end

# Setup a test app
module Rollcall
  class Application < Rails::Application; end
end

Rollcall::Application.config.secret_token = '1234567890123456789012345678901234567890'
Rollcall::Application.config.secret_key_base = '1234567890123456789012345678901234567890'