module ActsAsTenant
  module ControllerExtensions
    module Subdomain
      extend ActiveSupport::Concern

      included do
        cattr_accessor :tenant_class, :tenant_column
        before_action :find_tenant_by_subdomain
      end

      private

      def find_tenant_by_subdomain
        if request.subdomains.last
          ActsAsTenant.current_tenant = tenant_class.where(tenant_column => request.subdomains.last.downcase).first
        end
      end
    end
  end
end
