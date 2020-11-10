ActiveRecord::Base.send(:include, ActsAsTenant::ModelExtensions)
ActionController::Base.extend ActsAsTenant::ControllerExtensions
