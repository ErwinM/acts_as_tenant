module ActsAsTenant::Sidekiq
  class BaseMiddleware
    def self.sidekiq_7_and_up?
      Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("7")
    end
  end

  # Get the current tenant and store in the message to be sent to Sidekiq.
  class Client < BaseMiddleware
    include Sidekiq::ClientMiddleware if sidekiq_7_and_up?

    def call(worker_class, msg, queue, redis_pool)
      if ActsAsTenant.current_tenant.present?
        msg["acts_as_tenant"] ||=
          {
            "class" => ActsAsTenant.current_tenant.class.name,
            "id" => ActsAsTenant.current_tenant.id
          }
      end

      yield
    end
  end

  # Pull the tenant out and run the current thread with it.
  class Server < BaseMiddleware
    include Sidekiq::ServerMiddleware if sidekiq_7_and_up?

    def call(worker_class, msg, queue)
      if msg.has_key?("acts_as_tenant")
        klass = msg["acts_as_tenant"]["class"].constantize
        id = msg["acts_as_tenant"]["id"]
        account = klass.class_eval(&ActsAsTenant.configuration.job_scope).find(id)
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
    elsif defined?(Sidekiq::Batch::Server)
      chain.insert_before Sidekiq::Batch::Server, ActsAsTenant::Sidekiq::Server
    else
      chain.add ActsAsTenant::Sidekiq::Server
    end
  end
end
