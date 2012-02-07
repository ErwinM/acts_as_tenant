module ActsAsTenant
  module ControllerExtensions
    
    # this method allows setting the current_tenant by reading the subdomain and looking
    # it up in the tenant-model passed to the method (defaults to Account). The method will 
    # look for the subdomain in a column referenced by the second argument (defaults to subdomain).
    def set_current_tenant_by_subdomain(tenant = :account, column = :subdomain )
      self.class_eval do
        cattr_accessor :tenant_class, :tenant_column
        attr_accessor :current_tenant
      end

      self.tenant_class = tenant.to_s.camelcase.constantize
      self.tenant_column = column.to_sym

      self.class_eval do
        before_filter :find_tenant_by_subdomain

        helper_method :current_tenant
        
        private
          def find_tenant_by_subdomain
            ActsAsTenant.current_tenant = tenant_class.where(tenant_column => request.subdomains.first).first
            @current_tenant_instance = ActsAsTenant.current_tenant
          end
          
          # helper method to have the current_tenant available in the controller  
          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end
    
    # this method allows manual setting of the current_tenant by passing in a tenant object
    # 
    def set_current_tenant_to(current_tenant_object)
      self.class_eval do
        cattr_accessor :tenant_class
        attr_accessor :current_tenant
        before_filter lambda { @current_tenant_instance = ActsAsTenant.current_tenant = current_tenant_object }
        
        helper_method :current_tenant
        
        private
          # helper method to have the current_tenant available in the controller  
          def current_tenant
            ActsAsTenant.current_tenant
          end
      end
    end
  end
end