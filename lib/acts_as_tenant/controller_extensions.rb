module ActsAsTenant
  module ControllerExtensions

    # this method allows setting the current_tenant by reading the subdomain and looking
    # it up in the tenant-model passed to the method. The method will look for the subdomain
    # in a column referenced by the second argument.
    def set_current_tenant_by_subdomain(tenant = :account, column = :subdomain )
      self.class_eval do
        cattr_accessor :tenant_class, :tenant_column
      end

      self.tenant_class = tenant.to_s.camelcase.constantize
      self.tenant_column = column.to_sym

      self.class_eval do

        before_action :find_tenant_by_subdomain
        helper_method :current_tenant if respond_to?(:helper_method)


        private
          def find_tenant_by_subdomain
            if request.subdomains.last
              ActsAsTenant.current_tenant = tenant_class.where(tenant_column => request.subdomains.last.downcase).first
            end
          end

          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end

    # 01/27/2014 Christian Yerena / @preth00nker
    # this method adds the possibility of use the domain as a possible second argument to find
    # the current_tenant.
    def set_current_tenant_by_subdomain_or_domain(tenant = :account, primary_column = :subdomain, second_column = :domain )
      self.class_eval do
        cattr_accessor :tenant_class, :tenant_primary_column, :tenant_second_column
      end

      self.tenant_class = tenant.to_s.camelcase.constantize
      self.tenant_primary_column = primary_column.to_sym
      self.tenant_second_column = second_column.to_sym

      self.class_eval do

        before_action :find_tenant_by_subdomain_or_domain
        helper_method :current_tenant if respond_to?(:helper_method)


        private
          def find_tenant_by_subdomain_or_domain
            if request.subdomains.last
              ActsAsTenant.current_tenant = tenant_class.where(tenant_primary_column => request.subdomains.last.downcase).first
            else
              ActsAsTenant.current_tenant = tenant_class.where(tenant_second_column => request.domain.downcase).first
            end
          end

          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end


    # This method sets up a method that allows manual setting of the current_tenant. This method should
    # be used in a before_action. In addition, a helper is setup that returns the current_tenant
    def set_current_tenant_through_filter
      self.class_eval do
        helper_method :current_tenant if respond_to?(:helper_method)

        private
          def set_current_tenant(current_tenant_object)
            ActsAsTenant.current_tenant = current_tenant_object
          end

          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end
  end
end
