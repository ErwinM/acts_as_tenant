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
  end
end
