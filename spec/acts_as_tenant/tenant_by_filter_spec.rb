require "spec_helper"

#Setup test specific ApplicationController
class Account
  attr_accessor :name
end

class ApplicationController2 < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_through_filter
  before_filter :your_method_that_finds_the_current_tenant

  def your_method_that_finds_the_current_tenant
    current_account = Account.new
    current_account.name = 'account1'
    set_current_tenant(current_account)
  end
  
end

# Start testing
describe ApplicationController2, :type => :controller do
  controller do
    def index
      render :text => "custom called"
    end
  end
  
  it 'Finds the correct tenant using the filter command' do
    get :index
    ActsAsTenant.current_tenant.name.should eq 'account1'
  end
end