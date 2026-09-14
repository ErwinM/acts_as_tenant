module ActsAsTenant
  module ActiveJobExtensions
    def self.prepended(base)
      # Resolve the tenant inside the perform callbacks so `rescue_from`, `retry_on`
      # and `discard_on` can handle a tenant that no longer exists.
      base.before_perform do
        ActsAsTenant.current_tenant = GlobalID::Locator.locate(@acts_as_tenant_global_id) if @acts_as_tenant_global_id
      end
    end

    def serialize
      # A deserialized job keeps the tenant it was enqueued with, e.g. when it is retried.
      tenant_global_id = defined?(@acts_as_tenant_global_id) ? @acts_as_tenant_global_id : ActsAsTenant.current_tenant&.to_global_id&.to_s
      super.merge("current_tenant" => tenant_global_id)
    end

    def deserialize(job_data)
      @acts_as_tenant_global_id = job_data.delete("current_tenant")
      super
    end

    def perform_now
      return super unless defined?(@acts_as_tenant_global_id)

      # Start without a tenant so a job enqueued without one never inherits the thread's,
      # and restore the thread's tenant once the job is done.
      ActsAsTenant.with_tenant(nil) { super }
    end
  end
end
