require 'rails/all'
require 'database_cleaner'

dbconfig = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.establish_connection(dbconfig[ENV['DB'] || 'sqlite'])

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
  end
end
