require "spec_helper"

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_by_subdomain
end

describe ApplicationController, type: :controller do
  let!(:account) { Account.create!(subdomain: "account1") }

  controller do
    def index
      render plain: "custom called"
    end
  end

  it "Finds the correct tenant with a subdomain.example.com" do
    @request.host = "account1.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end

  it "Finds the correct tenant with a www.subdomain.example.com" do
    @request.host = "www.account1.example.com"
    get :index
    expect(ActsAsTenant.current_tenant).to eq account
  end
end
