module ActsAsTenant
  class Configuration
    attr_writer :require_tenant, :pkey

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
  end
end
