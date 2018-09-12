require "request_store"

#$LOAD_PATH.unshift(File.dirname(__FILE__))

require "acts_as_tenant/version"
require "acts_as_tenant/errors"
require "acts_as_tenant/configuration"
require "acts_as_tenant/controller_extensions"
require "acts_as_tenant/model_extensions"

#$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, ActsAsTenant::ModelExtensions)
end

if defined?(ActionController::Base)
  ActiveSupport.on_load(:action_controller) do
    ActionController::Base.extend ActsAsTenant::ControllerExtensions
  end
end

if defined?(ActionController::API)
  ActiveSupport.on_load(:action_controller) do
    ActionController::API.extend ActsAsTenant::ControllerExtensions
  end
end

module ActsAsTenant
end
