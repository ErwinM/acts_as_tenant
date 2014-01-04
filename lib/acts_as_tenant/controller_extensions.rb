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
        before_filter :find_tenant_by_subdomain
        helper_method :current_tenant
        
        private
          def find_tenant_by_subdomain
            ActsAsTenant.current_tenant = tenant_class.where(tenant_column => request.subdomains.last).first
          end
          
          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end
    
    # This method sets up a method that allows manual setting of the current_tenant. This method should
    # be used in a before_filter. In addition, a helper is setup that returns the current_tenant
    def set_current_tenant_through_filter
      self.class_eval do
        helper_method :current_tenant
        
        def set_current_tenant(current_tenant_object)
          ActsAsTenant.current_tenant = current_tenant_object
        end
        
        private 
          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end
  end
end