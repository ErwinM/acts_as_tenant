module ActsAsTenant
  module ChannelExtensions
    module Subdomain
      extend ActiveSupport::Concern

      included do
        cattr_accessor :tenant_class, :tenant_column, :subdomain_lookup
        before_subscribe :find_tenant_by_subdomain
      end

      private

      def find_tenant_by_subdomain
        if (subdomain = request.subdomains.send(subdomain_lookup))
          ActsAsTenant.current_tenant = tenant_class.where(tenant_column => subdomain.downcase).first
        end
      end

      def request
        @request ||= ActionDispatch::Request.new(connection.env)
      end
    end
  end
end
