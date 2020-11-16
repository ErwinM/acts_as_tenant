require "request_store"

require "acts_as_tenant/version"
require "acts_as_tenant/errors"

module ActsAsTenant
  autoload :Configuration, "acts_as_tenant/configuration"
  autoload :ControllerExtensions, "acts_as_tenant/controller_extensions"
  autoload :ModelExtensions, "acts_as_tenant/model_extensions"
  autoload :TenantHelper, "acts_as_tenant/tenant_helper"

  @@configuration = nil
  @@tenant_klass = nil
  @@models_with_global_records = []

  class << self
    attr_accessor :test_tenant
    attr_writer :default_tenant
  end

  def self.configure
    @@configuration = Configuration.new
    yield configuration if block_given?
    configuration
  end

  def self.configuration
    @@configuration || configure
  end

  def self.set_tenant_klass(klass)
    @@tenant_klass = klass
  end

  def self.tenant_klass
    @@tenant_klass
  end

  def self.models_with_global_records
    @@models_with_global_records
  end

  def self.add_global_record_model model
    @@models_with_global_records.push(model)
  end

  def self.fkey
    "#{@@tenant_klass}_id"
  end

  def self.pkey
    ActsAsTenant.configuration.pkey
  end

  def self.polymorphic_type
    "#{@@tenant_klass}_type"
  end

  def self.current_tenant=(tenant)
    RequestStore.store[:current_tenant] = tenant
  end

  def self.current_tenant
    RequestStore.store[:current_tenant] || test_tenant || default_tenant
  end

  def self.unscoped=(unscoped)
    RequestStore.store[:acts_as_tenant_unscoped] = unscoped
  end

  def self.unscoped
    RequestStore.store[:acts_as_tenant_unscoped]
  end

  def self.unscoped?
    !!unscoped
  end

  def self.default_tenant
    @default_tenant unless unscoped
  end

  def self.with_tenant(tenant, &block)
    if block.nil?
      raise ArgumentError, "block required"
    end

    old_tenant = current_tenant
    self.current_tenant = tenant
    value = block.call
    value
  ensure
    self.current_tenant = old_tenant
  end

  def self.without_tenant(&block)
    if block.nil?
      raise ArgumentError, "block required"
    end

    old_tenant = current_tenant
    old_unscoped = unscoped

    self.current_tenant = nil
    self.unscoped = true
    value = block.call
    value
  ensure
    self.current_tenant = old_tenant
    self.unscoped = old_unscoped
  end
end

ActiveSupport.on_load(:active_record) do |base|
  base.include ActsAsTenant::ModelExtensions
end

ActiveSupport.on_load(:action_controller) do |base|
  base.extend ActsAsTenant::ControllerExtensions
  base.include ActsAsTenant::TenantHelper
end

ActiveSupport.on_load(:action_view) do |base|
  base.include ActsAsTenant::TenantHelper
end
