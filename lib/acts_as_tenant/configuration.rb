module ActsAsTenant
  class Configuration
    attr_writer :require_tenant, :pkey
    attr_accessor :tenant_change_hook

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
      @job_scope = wrap_scope(scope)
    end

    def association_validation_scope
      @association_validation_scope || ->(relation) { relation }
    end

    # Used for looking up associated records when validating belongs_to associations
    #
    # Format matches Rails scopes
    #
    #   association_validation_scope = ->(relation) {}
    #   association_validation_scope = -> {}
    def association_validation_scope=(scope)
      @association_validation_scope = wrap_scope(scope)
    end

    private

    # Scopes without arguments are evaluated on the relation
    def wrap_scope(scope)
      if scope && scope.arity == 0
        proc { instance_exec(&scope) }
      else
        scope
      end
    end
  end
end
