module ActsAsTenant
  module ChannelExtensions
    module Filter
      extend ActiveSupport::Concern

      private

      def set_current_tenant(current_tenant_object)
        ActsAsTenant.current_tenant = current_tenant_object
      end
    end
  end
end
