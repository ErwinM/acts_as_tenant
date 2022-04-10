module ActsAsTenant
  class Configuration
    attr_writer :require_tenant, :pkey, :multi_tenanted

    def require_tenant
      @require_tenant ||= false
    end

    def multi_tenanted
      @multi_tenanted ||= false
    end

    def pkey
      @pkey ||= :id
    end
  end
end
