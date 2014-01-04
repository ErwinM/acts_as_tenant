require "spec_helper"

#Setup test specific ApplicationController
class Account; end # this is so the spec will work in isolation

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_by_subdomain
end

# Start testing
describe ApplicationController, :type => :controller do
  controller do
    def index
      render :text => "custom called"
    end
  end
  
  it 'Finds the correct tenant with a subdomain.example.com' do
    @request.host = "account1.example.com"
    Account.should_receive(:where).with({subdomain: 'account1'}) {['account1']}
    get :index
    ActsAsTenant.current_tenant.should eq 'account1'
  end
  
  it 'Finds the correct tenant with a www.subdomain.example.com' do
    @request.host = "www.account1.example.com"
    Account.should_receive(:where).with({subdomain: 'account1'}) {['account1']}
    get :index
    ActsAsTenant.current_tenant.should eq 'account1'
  end
end