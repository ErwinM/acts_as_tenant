module ActsAsTenant
  module ControllerExtensions
    module Filter
      extend ActiveSupport::Concern

      private

      def set_current_master_tenant(current_master_tenant_object)
        ActsAsTenant.current_master_tenant = current_master_tenant_object
      end

      def set_current_tenant(current_tenant_object)
        ActsAsTenant.current_tenant = current_tenant_object
      end
    end
  end
end
