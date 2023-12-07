require "spec_helper"
require "acts_as_tenant/sidekiq"

describe "ActsAsTenant::Sidekiq" do
  let(:account) { Account.new(id: 1234) }
  let(:message) { {"acts_as_tenant" => {"class" => "Account", "id" => 1234}} }

  describe "ActsAsTenant::Sidekiq::Client" do
    subject { ActsAsTenant::Sidekiq::Client.new }

    it "saves tenant if present" do
      ActsAsTenant.current_tenant = account

      msg = {}
      subject.call(nil, msg, nil, nil) {}
      expect(msg).to eq message
    end

    it "does not set tenant if not present" do
      expect(ActsAsTenant.current_tenant).to be_nil

      msg = {}
      subject.call(nil, msg, nil, nil) {}
      expect(msg).not_to eq message
    end
  end

  describe "ActsAsTenant::Sidekiq::Server" do
    subject { ActsAsTenant::Sidekiq::Server.new }

    it "restores tenant if tenant saved" do
      Account.create!(id: 1234)
      msg = message
      subject.call(nil, msg, nil) do
        expect(ActsAsTenant.current_tenant).to be_a_kind_of Account
      end
      expect(ActsAsTenant.current_tenant).to be_nil
    end

    it "runs without tenant if no tenant saved" do
      expect(Account).not_to receive(:find)

      msg = {}
      subject.call(nil, msg, nil) do
        expect(ActsAsTenant.current_tenant).to be_nil
      end
      expect(ActsAsTenant.current_tenant).to be_nil
    end

    it "restores tenant with custom scope" do
      original_job_scope = ActsAsTenant.configuration.job_scope
      ActsAsTenant.configuration.job_scope = -> { unscope(where: :deleted_at) }

      Account.create!(id: 1234, deleted_at: 1.day.ago)
      msg = message
      subject.call(nil, msg, nil) do
        expect(ActsAsTenant.current_tenant).to be_a_kind_of Account
      end
      expect(ActsAsTenant.current_tenant).to be_nil
    ensure
      ActsAsTenant.configuration.job_scope = original_job_scope
    end
  end

  it "includes ActsAsTenant client middleware" do
    if ActsAsTenant::Sidekiq::BaseMiddleware.sidekiq_7_and_up?
      expect(Sidekiq.default_configuration.client_middleware.exists?(ActsAsTenant::Sidekiq::Client)).to eq(true)
    else
      expect(Sidekiq.client_middleware.exists?(ActsAsTenant::Sidekiq::Client)).to eq(true)
    end
  end

  # unable to test server configuration
end
