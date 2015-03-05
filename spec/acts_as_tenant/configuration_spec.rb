require 'spec_helper'

describe ActsAsTenant::Configuration do
  describe 'no configuration given' do
    before do
      ActsAsTenant.configure
    end

    it 'provides defaults' do
      expect(ActsAsTenant.configuration.require_tenant).not_to be_truthy
    end
  end

  describe 'with config block' do
    after do
      ActsAsTenant.configure
    end

    it 'stores config' do
      ActsAsTenant.configure do |config|
        config.require_tenant = true
        config.allow_fallback = true
      end

      expect(ActsAsTenant.configuration.require_tenant).to eq(true)
      expect(ActsAsTenant.configuration.allow_fallback).to eq(true)
    end

  end
end
