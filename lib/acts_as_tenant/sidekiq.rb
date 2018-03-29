module ActsAsTenant::Sidekiq
  # Get the current tenant and store in the message to be sent to Sidekiq.
  class Client
    def call(worker_class, msg, queue, redis_pool)
      msg['acts_as_tenant'] ||=
        {
            'class' => ActsAsTenant.current_tenant.class.name,
            'id' => ActsAsTenant.current_tenant.id
        } if ActsAsTenant.current_tenant.present?

      yield
    end
  end

  # Pull the tenant out and run the current thread with it.
  class Server
    def call(worker_class, msg, queue)
      if msg.has_key?('acts_as_tenant')
        account = msg['acts_as_tenant']['class'].constantize.find msg['acts_as_tenant']['id']
        ActsAsTenant.with_tenant account do
          yield
        end
      else
        yield
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add ActsAsTenant::Sidekiq::Client
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.add ActsAsTenant::Sidekiq::Client
  end
  config.server_middleware do |chain|
    if defined?(Sidekiq::Middleware::Server::RetryJobs)
      chain.insert_before Sidekiq::Middleware::Server::RetryJobs, ActsAsTenant::Sidekiq::Server
    else
      chain.add ActsAsTenant::Sidekiq::Server
    end
  end
end
