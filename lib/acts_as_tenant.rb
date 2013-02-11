#RAILS_3 = ::ActiveRecord::VERSION::MAJOR >= 3

require "active_record"
require "action_controller"
require "active_model"

#$LOAD_PATH.unshift(File.dirname(__FILE__))

require "acts_as_tenant"
require "acts_as_tenant/version"
require "acts_as_tenant/configuration"
require "acts_as_tenant/controller_extensions"
require "acts_as_tenant/model_extensions"

#$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, ActsAsTenant::ModelExtensions)
  ActionController::Base.extend ActsAsTenant::ControllerExtensions
end

module ActsAsTenant
end
  