require "spec_helper"

class SpecSubdomainChannel < ApplicationCable::Channel
  set_current_tenant_by_subdomain

  def subscribed
    reject if params[:room_id].nil?
  end

  def whoami
    transmit current_tenant.name
  end
end

class SpecSubdomainWithLookupChannel < ApplicationCable::Channel
  set_current_tenant_by_subdomain subdomain_lookup: :first

  def subscribed
    reject if params[:room_id].nil?
  end

  def whoami
    transmit current_tenant.name
  end
end

describe SpecSubdomainChannel, type: :channel do
  let(:account) { accounts(:with_domain) }

  before do
    @request = ActionCable::Connection::TestRequest.create
  end

  def connect
    stub_connection(env: @request.env)
    subscribe(room_id: 42)
  end

  it "finds the correct tenant with a subdomain.example.com" do
    @request.host = "#{account.subdomain}.example.com"
    connect

    expect(subscription).to be_confirmed
    expect(ActsAsTenant.current_tenant).to eq account

    perform :whoami
    expect(transmissions.last).to eq account.subdomain
  end

  it "finds the correct tenant with a www.subdomain.example.com" do
    @request.host = "www.#{account.subdomain}.example.com"
    connect

    expect(subscription).to be_confirmed
    expect(ActsAsTenant.current_tenant).to eq account

    perform :whoami
    expect(transmissions.last).to eq account.subdomain
  end

  it "ignores case when finding tenant by subdomain" do
    @request.host = "#{account.subdomain.upcase}.example.com"
    connect

    expect(subscription).to be_confirmed
    expect(ActsAsTenant.current_tenant).to eq account

    perform :whoami
    expect(transmissions.last).to eq account.subdomain
  end
end

describe SpecSubdomainWithLookupChannel, type: :channel do
  let(:account) { accounts(:with_domain) }

  before do
    @request = ActionCable::Connection::TestRequest.create
  end

  def connect
    stub_connection(env: @request.env)
    subscribe(room_id: 42)
  end

  it "allows overriding the subdomain lookup" do
    @request.host = "#{account.subdomain}.another.example.com"
    connect

    expect(subscription).to be_confirmed
    expect(ActsAsTenant.current_tenant).to eq account

    perform :whoami
    expect(transmissions.last).to eq account.subdomain
  end
end
