module ActsAsTenant
  module ControllerExtensions
    module SubdomainOrDomain
      extend ActiveSupport::Concern

      included do
        cattr_accessor :tenant_class, :tenant_primary_column, :tenant_second_column
        before_action :find_tenant_by_subdomain_or_domain
      end

      private

      def find_tenant_by_subdomain_or_domain
        ActsAsTenant.current_tenant = if request.subdomains.last
          tenant_class.where(tenant_primary_column => request.subdomains.last.downcase).first
        else
          tenant_class.where(tenant_second_column => request.domain.downcase).first
        end
      end
    end
  end
end
