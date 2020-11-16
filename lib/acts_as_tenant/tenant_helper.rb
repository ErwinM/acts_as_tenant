module ActsAsTenant
  module TenantHelper
    def current_tenant
      ActsAsTenant.current_tenant
    end
  end
end
