require "action_controller/railtie"
require "action_mailer/railtie"
require 'mongoid'
require 'database_cleaner'

Mongoid.logger = Moped.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
Mongoid.logger.level = Moped.logger.level = Logger::DEBUG
Mongoid.load!(File.join(File.dirname(__FILE__), "/mongoid.yml"), :test)

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
