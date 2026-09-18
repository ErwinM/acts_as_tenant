require "spec_helper"

describe ActsAsTenant::Configuration do
  after { ActsAsTenant.configure }

  it "provides defaults" do
    expect(ActsAsTenant.configuration.require_tenant).not_to be_truthy
  end

  it "stores config" do
    ActsAsTenant.configure do |config|
      config.require_tenant = true
    end

    expect(ActsAsTenant.configuration.require_tenant).to eq(true)
  end

  describe "#should_require_tenant?" do
    it "evaluates lambda" do
      ActsAsTenant.configure do |config|
        config.require_tenant = lambda { true }
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(true)

      ActsAsTenant.configure do |config|
        config.require_tenant = lambda { false }
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(false)
    end

    it "evaluates lambda with context" do
      account = accounts(:foo)
      test_context = nil

      ActsAsTenant.configure do |config|
        config.require_tenant = ->(context) {
          test_context = context
          context.klass.name == "Project"
        }
      end

      expect { account.projects.create!(name: "foobar") }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      expect(test_context.klass.name).to eq("Project")
    end

    it "evaluates callable object" do
      policy = Class.new do
        def self.call
          true
        end
      end

      ActsAsTenant.configure do |config|
        config.require_tenant = policy
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(true)
    end

    it "evaluates callable object with context" do
      policy = Class.new do
        def self.call(context)
          context.klass.name == "Project"
        end
      end

      ActsAsTenant.configure do |config|
        config.require_tenant = policy
      end

      expect { accounts(:foo).projects.create!(name: "foobar") }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it "evaluates boolean" do
      ActsAsTenant.configure do |config|
        config.require_tenant = true
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(true)

      ActsAsTenant.configure do |config|
        config.require_tenant = false
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(false)
    end

    it "evaluates truthy" do
      ActsAsTenant.configure do |config|
        config.require_tenant = "foobar"
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(true)
    end

    it "evaluates falsy" do
      ActsAsTenant.configure do |config|
        config.require_tenant = nil
      end

      expect(ActsAsTenant.should_require_tenant?).to eq(false)
    end

    it "runs a hook on current_tenant" do
      truthy = false
      ActsAsTenant.configure do |config|
        config.tenant_change_hook = lambda do |tenant|
          truthy = true
        end
      end

      ActsAsTenant.current_tenant = "foobar"

      expect(truthy).to eq(true)
    end

    it "runs a hook on with_tenant" do
      truthy = false
      ActsAsTenant.configure do |config|
        config.tenant_change_hook = lambda do |tenant|
          truthy = true
        end
      end

      ActsAsTenant.with_tenant("foobar") do
        # do nothing
      end

      expect(truthy).to eq(true)
    end

    it "runs the hook with nil when Current is reset" do
      tenants = []
      ActsAsTenant.configure do |config|
        config.tenant_change_hook = ->(tenant) { tenants << tenant }
      end

      ActsAsTenant.current_tenant = "foobar"
      ActsAsTenant::Current.reset

      expect(tenants).to eq(["foobar", nil])
    end

    it "accepts any callable as a hook" do
      hook = Class.new do
        def self.call(tenant)
          @tenant = tenant
        end

        def self.tenant
          @tenant
        end
      end

      ActsAsTenant.configure do |config|
        config.tenant_change_hook = hook
      end

      ActsAsTenant.current_tenant = "foobar"

      expect(hook.tenant).to eq("foobar")
    end

    it "can remove the hook" do
      ActsAsTenant.configure do |config|
        config.tenant_change_hook = ->(tenant) { raise "should not be called" }
        config.tenant_change_hook = nil
      end

      expect { ActsAsTenant.current_tenant = "foobar" }.not_to raise_error
    end

    it "sets current_tenant before anything is configured" do
      ActsAsTenant.class_variable_set(:@@configuration, nil)

      expect { ActsAsTenant.current_tenant = "foobar" }.not_to raise_error
      expect(ActsAsTenant.current_tenant).to eq("foobar")
    end
  end
end
