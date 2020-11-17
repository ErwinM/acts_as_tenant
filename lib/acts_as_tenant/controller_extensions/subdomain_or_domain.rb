module ActsAsTenant
  module ControllerExtensions
    module SubdomainOrDomain
      extend ActiveSupport::Concern

      included do
        cattr_accessor :tenant_class, :tenant_primary_column, :tenant_second_column, :subdomain_lookup
        before_action :find_tenant_by_subdomain_or_domain
      end

      private

      def find_tenant_by_subdomain_or_domain
        subdomain = request.subdomains.send(subdomain_lookup)
        query = subdomain.present? ? {tenant_primary_column => subdomain.downcase} : {tenant_second_column => request.domain.downcase}
        ActsAsTenant.current_tenant = tenant_class.where(query).first
      end
    end
  end
end
