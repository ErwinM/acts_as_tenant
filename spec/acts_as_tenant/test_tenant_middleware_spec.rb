require 'spec_helper'
require 'acts_as_tenant/test_tenant_middleware'
require 'active_record_models'

describe ActsAsTenant::TestTenantMiddleware do
  after { ActsAsTenant.current_tenant = nil }
  subject { request.get('/some/path') }

  let(:middleware) { described_class.new(app) }
  let(:request) { Rack::MockRequest.new(middleware) }

  let!(:account1) { Account.create }
  let!(:account2) { Account.create }

  class TestRackApp1
    def call(_env)
      ActsAsTenant.current_tenant = Account.first
      TestReceiver.assert_current_id(ActsAsTenant.current_tenant.id)
      ActsAsTenant.current_tenant = nil
      [200, {}, ['OK']]
    end
  end

  class TestRackApp2
    def call(_env)
      TestReceiver.assert_current_id(ActsAsTenant.current_tenant.try(:id))
      [200, {}, ['OK']]
    end
  end

  class TestReceiver
    def self.assert_current_id(id); end
  end

  context 'when test_tenant is nil before processing' do
    before { ActsAsTenant.test_tenant = nil }

    context 'that switches tenancies' do
      let(:app) { TestRackApp1.new }

      it 'should remain nil after processing' do
        expect(ActsAsTenant.current_tenant).to be_nil
        expect(TestReceiver).to receive(:assert_current_id).with(account1.id)
        expect(subject.status).to eq 200
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end

    context 'that does not switch tenancies' do
      let(:app) { TestRackApp2.new }

      it 'should remain nil after processing' do
        expect(ActsAsTenant.current_tenant).to be_nil
        expect(TestReceiver).to receive(:assert_current_id).with(nil)
        expect(subject.status).to eq 200
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end
  end

  context 'when test_tenant is assigned before processing' do
    before { ActsAsTenant.test_tenant = account2 }

    context 'that switches tenancies' do
      let(:app) { TestRackApp1.new }

      it 'should remain assigned after processing' do
        expect(ActsAsTenant.current_tenant).to eq account2
        expect(TestReceiver).to receive(:assert_current_id).with(account1.id)
        expect(subject.status).to eq 200
        expect(ActsAsTenant.current_tenant).to eq account2
      end
    end

    context 'that does not switch tenancies' do
      let(:app) { TestRackApp2.new }

      it 'should remain assigned after processing' do
        expect(ActsAsTenant.current_tenant).to eq account2
        expect(TestReceiver).to receive(:assert_current_id).with(nil)
        expect(subject.status).to eq 200
        expect(ActsAsTenant.current_tenant).to eq account2
      end
    end
  end
end
