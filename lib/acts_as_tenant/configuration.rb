module ActsAsTenant
  class Configuration
    attr_writer :require_tenant, :pkey
    attr_reader :tenant_change_hook

    def require_tenant
      @require_tenant ||= false
    end

    def pkey
      @pkey ||= :id
    end

    def job_scope
      @job_scope || ->(relation) { relation.all }
    end

    # Used for looking job tenants in background jobs
    #
    # Format matches Rails scopes
    #
    #   job_scope = ->(relation) {}
    #   job_scope = -> {}
    def job_scope=(scope)
      @job_scope = if scope && scope.arity == 0
        proc { instance_exec(&scope) }
      else
        scope
      end
    end

    def tenant_change_hook=(hook)
      raise(ArgumentError, "tenant_change_hook must be a Proc") unless hook.is_a?(Proc)
      @tenant_change_hook = hook
    end
  end
end
