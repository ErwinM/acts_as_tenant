ActiveSupport.on_load(:active_record_base) do
  ActiveRecord::Base.send(:include, ActsAsTenant::ModelExtensions)
end
ActionController::Base.extend ActsAsTenant::ControllerExtensions
