require "spec_helper"

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

    context "when tenant exist" do
      before { account.save }

      it "restores tenant" do
        msg = message
        subject.call(nil, msg, nil) do
          expect(ActsAsTenant.current_tenant).to be_a_kind_of Account
        end
        expect(ActsAsTenant.current_tenant).to be_nil
      end

      context "but it is outside its own scope" do
        before { account.update!(deleted_at: Time.now) }

        it "ignores the scope and sets the tenant" do
          msg = {}
          subject.call(nil, message, nil) do
            expect(ActsAsTenant.current_tenant).to eq(account)
          end
        end
      end
    end

    context "when tenant does not exist" do
      it "runs without tenant" do
        msg = {}
        subject.call(nil, msg, nil) do
          expect(ActsAsTenant.current_tenant).to be_nil
        end
        expect(ActsAsTenant.current_tenant).to be_nil
      end
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
