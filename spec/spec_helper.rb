$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

$orm = ENV["ORM"] || "active_record"
require 'yaml'
require "#{$orm}_helper"

require 'rspec/rails'
require 'acts_as_tenant'

RSpec.configure do |config|
  config.after(:each) do
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
