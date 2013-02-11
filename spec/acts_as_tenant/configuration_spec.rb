require 'spec_helper'

describe ActsAsTenant::Configuration do
  describe 'no configuration given' do
    before do
      ActsAsTenant.configure
    end

    it 'provides defaults' do
      ActsAsTenant.configuration.require_tenant.should_not be_true
    end
  end

  describe 'with config block' do
    after do
      ActsAsTenant.configure
    end

    it 'stores config' do
      ActsAsTenant.configure do |config|
        config.require_tenant = true
      end

      ActsAsTenant.configuration.require_tenant.should be_true
    end

  end
end
