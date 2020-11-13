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
end
