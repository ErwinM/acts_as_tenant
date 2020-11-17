require "spec_helper"

class SubdomainController < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_by_subdomain
end

describe SubdomainController, type: :controller do
  let(:account) { accounts(:with_domain) }

  controller(SubdomainController) do
    def index
      # Exercise current_tenant helper method
      render plain: current_tenant.name
    end
  end

  it "finds the correct tenant with a subdomain.example.com" do
    @request.host = "#{account.subdomain}.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
    expect(response.body).to eq(account.subdomain)
  end

  it "finds the correct tenant with a www.subdomain.example.com" do
    @request.host = "www.#{account.subdomain}.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
    expect(response.body).to eq(account.subdomain)
  end

  it "ignores case when finding tenant by subdomain" do
    @request.host = "#{account.subdomain.upcase}.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end

  context "overriding subdomain lookup" do
    after { controller.subdomain_lookup = :last }

    it "allows overriding the subdomain lookup" do
      controller.subdomain_lookup = :first
      @request.host = "#{account.subdomain}.another.example.com"
      get :index
      expect(ActsAsTenant.current_tenant).to eq account
      expect(response.body).to eq(account.subdomain)
    end
  end
end
