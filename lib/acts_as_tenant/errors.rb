module ActsAsTenant
  class Error < StandardError
  end

  module Errors
    class ModelNotScopedByTenant < ActsAsTenant::Error
      #"[ActsAsTenant] validates_uniqueness_to_tenant: no current tenant"
    end
    
    class NoTenantSet < ActsAsTenant::Error
      # "No tenant found, while tenant_required is set to true [ActsAsTenant]"
    end
    
    class ModelNotScopedByTenant < ActsAsTenant::Error
    end
    
    class TenantIsImmutable < ActsAsTenant::Error
    end
    
  end
end
