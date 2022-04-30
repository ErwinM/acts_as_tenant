module ActsAsTenant
  module TenantHelper
    def current_master_tenant
      ActsAsTenant.current_master_tenant
    end

    def current_tenant
      ActsAsTenant.current_tenant
    end
  end
end
