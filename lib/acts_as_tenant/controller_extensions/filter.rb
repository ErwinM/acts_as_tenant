module ActsAsTenant
  module ControllerExtensions
    module Filter
      extend ActiveSupport::Concern

      included do
        helper_method :current_tenant if respond_to?(:helper_method)
      end

      private

      def set_current_tenant(current_tenant_object)
        ActsAsTenant.current_tenant = current_tenant_object
      end
    end
  end
end
