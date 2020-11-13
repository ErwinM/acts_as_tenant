require "spec_helper"

class ApplicationController2 < ActionController::Base
  include Rails.application.routes.url_helpers
  set_current_tenant_through_filter
  before_action :your_method_that_finds_the_current_tenant

  def your_method_that_finds_the_current_tenant
    current_account = Account.new(name: "account1")
    set_current_tenant(current_account)
  end
end

# Start testing
describe ApplicationController2, type: :controller do
  controller do
    def index
      render plain: "custom called"
    end
  end

  it "Finds the correct tenant using the filter command" do
    get :index
    expect(ActsAsTenant.current_tenant.name).to eq "account1"
  end
end
