module Delayed
  module Backend
    module Base
      module ClassMethods
        # Add a job to the queue
        def enqueue(*args)
          if ActsAsTenant.current_tenant
            args[0].job_data["acts_as_tenant"] = {
              "tenant_class" => ActsAsTenant.current_tenant.class.name,
              "tenant_id" => ActsAsTenant.current_tenant.id
            }
          end

          job_options = Delayed::Backend::JobPreparer.new(*args).prepare
          enqueue_job(job_options)
        end
      end
    end
  end
end

module DelayedJobAdapterMonkeyPatch
  def perform
    if tenant_account
      ActsAsTenant.with_tenant(tenant_account) do
        super
      end
    else
      super
    end
  end

  def tenant_account
    @tenant_account ||= begin
      account = job_data.delete("acts_as_tenant")
      return unless account

      account["tenant_class"].constantize.find(account["tenant_id"])
    end
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(DelayedJobAdapterMonkeyPatch)
