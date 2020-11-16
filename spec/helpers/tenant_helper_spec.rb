require "spec_helper"

describe ActsAsTenant::TenantHelper, type: :helper do
  describe "#current_tenant" do
    it "returns nil if no tenant set" do
      expect(helper.current_tenant).to be_nil
    end

    it "returns nil if no tenant set" do
      ActsAsTenant.current_tenant = accounts(:foo)
      expect(helper.current_tenant).to eq(accounts(:foo))
    end
  end
end
