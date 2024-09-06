require "spec_helper"

class SpecFilterChannel < ApplicationCable::Channel
  set_current_tenant_through_filter
  before_subscribe :your_method_that_finds_the_current_tenant

  def subscribed
    reject if params[:room_id].nil?
  end

  def whoami
    transmit current_tenant.name
  end

  private

  def your_method_that_finds_the_current_tenant
    current_account = Account.new(name: "account1")
    set_current_tenant(current_account)
  end
end

describe SpecFilterChannel, type: :channel do
  before do
    stub_connection
  end

  it "Finds the correct tenant using the filter command" do
    subscribe(room_id: 42)

    expect(subscription).to be_confirmed
    expect(ActsAsTenant.current_tenant.name).to eq "account1"

    perform :whoami
    expect(transmissions.last).to eq("account1")
  end
end
