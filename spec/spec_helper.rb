$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'active_record'
require 'action_controller'
require 'logger'

require 'acts_as_tenant/model_extensions'
require 'acts_as_tenant/controller_extensions'

ActiveRecord::Base.send(:include, ActsAsTenant::ModelExtensions)
ActionController::Base.extend ActsAsTenant::ControllerExtensions

config = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite'])

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

#RSpec.configure do |config|
  
#end