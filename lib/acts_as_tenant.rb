require "request_store"

#$LOAD_PATH.unshift(File.dirname(__FILE__))

require "acts_as_tenant/version"
require "acts_as_tenant/errors"
require "acts_as_tenant/configuration"
require "acts_as_tenant/controller_extensions"
require "acts_as_tenant/model_extensions"

#$LOAD_PATH.shift

ActiveSupport.on_load(:active_record) do |base|
  base.include ActsAsTenant::ModelExtensions
end

ActiveSupport.on_load(:action_controller) do |base|
  base.extend ActsAsTenant::ControllerExtensions
end

module ActsAsTenant
end
