require "spec_helper"

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_by_subdomain_or_domain
end

describe ApplicationController, type: :controller do
  let!(:account) { Account.create!(subdomain: "subdomain", domain: "example.com") }

  controller(ApplicationController) do
    def index
      render plain: "custom called"
    end
  end

  it "Finds the correct tenant with a example1.com" do
    @request.host = "example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end

  it "Finds the correct tenant with a subdomain.example.com" do
    @request.host = "subdomain.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end

  it "Finds the correct tenant with a www.subdomain.example.com" do
    @request.host = "subdomain.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end

  it "Ignores case when finding tenant by subdomain" do
    @request.host = "SubDomain.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end
end
