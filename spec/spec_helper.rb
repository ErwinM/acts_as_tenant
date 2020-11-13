$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require "rails/all"

# Setup a test app
module Rollcall
  class Application < Rails::Application; end
end

Rollcall::Application.config.secret_key_base = "1234567890123456789012345678901234567890"

require "rspec/rails"
require "acts_as_tenant"
require "active_record_helper"
require "active_record_models"

RSpec.configure do |config|
  config.after(:each) do
    ActsAsTenant.current_tenant = nil
  end

  config.infer_base_class_for_anonymous_controllers = true
end
