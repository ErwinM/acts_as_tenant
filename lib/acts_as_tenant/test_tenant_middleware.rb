module ActsAsTenant
  class TestTenantMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      previously_set_test_tenant = ActsAsTenant.test_tenant
      ActsAsTenant.test_tenant = nil
      @app.call(env)
    ensure
      ActsAsTenant.test_tenant = previously_set_test_tenant
    end
  end
end
