require "spec_helper"

describe ActionView::Base, type: :helper do
  it "responds ot current_tenant" do
    expect(helper).to respond_to(:current_tenant)
  end

  it "returns nil if no tenant set" do
    expect(helper.current_tenant).to be_nil
  end

  it "returns the current tenant" do
    ActsAsTenant.current_tenant = accounts(:foo)
    expect(helper.current_tenant).to eq(accounts(:foo))
  end
end
