module ActsAsTenant
  class Configuration
    attr_writer :require_tenant, :pkey

    def require_tenant
      @require_tenant ||= false
    end

    def pkey
      @pkey ||= :id
    end
  end
end
