module ActsAsTenant
  module ControllerExtensions
    module Subdomain
      extend ActiveSupport::Concern

      included do
        cattr_accessor :tenant_class, :tenant_column, :subdomain_lookup
        before_action :find_tenant_by_subdomain
      end

      private

      def find_tenant_by_subdomain
        if (subdomain = request.subdomains.send(subdomain_lookup))
          ActsAsTenant.current_tenant = tenant_class.where(tenant_column => subdomain.downcase).first
        end
      end
    end
  end
end
