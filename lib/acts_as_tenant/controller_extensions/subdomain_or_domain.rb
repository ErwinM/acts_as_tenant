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
        subdomain = request.subdomains.public_send(subdomain_lookup)
        domain = request.domain

        # request.domain is nil for IP addresses, so there is no tenant to look up
        query = if subdomain.present?
          {tenant_primary_column => subdomain.downcase}
        elsif domain.present?
          {tenant_second_column => domain.downcase}
        end

        ActsAsTenant.current_tenant = query && tenant_class.find_by(query)
      end
    end
  end
end
