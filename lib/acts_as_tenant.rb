require "active_support/current_attributes"
require "acts_as_tenant/version"
require "acts_as_tenant/errors"

module ActsAsTenant
  autoload :Configuration, "acts_as_tenant/configuration"
  autoload :ControllerExtensions, "acts_as_tenant/controller_extensions"
  autoload :ModelExtensions, "acts_as_tenant/model_extensions"
  autoload :TenantHelper, "acts_as_tenant/tenant_helper"
  autoload :ActiveJobExtensions, "acts_as_tenant/active_job_extensions"

  @@configuration = nil
  @@tenant_klass = nil
  @@models_with_global_records = []
  @@mutable_tenant = false

  class Current < ActiveSupport::CurrentAttributes
    attribute :current_tenant, :acts_as_tenant_unscoped

    def current_tenant=(tenant)
      super.tap do
        configuration.tenant_change_hook.call(tenant) if configuration.tenant_change_hook.present?
      end
    end

    def configuration
      Module.nesting.last.class_variable_get(:@@configuration)
    end
  end

  class << self
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
    Current.current_tenant = tenant
  end

  def self.current_tenant
    Current.current_tenant || test_tenant || default_tenant
  end

  def self.test_tenant=(tenant)
    Thread.current[:test_tenant] = tenant
  end

  def self.test_tenant
    Thread.current[:test_tenant]
  end

  def self.unscoped=(unscoped)
    Current.acts_as_tenant_unscoped = unscoped
  end

  def self.unscoped
    Current.acts_as_tenant_unscoped
  end

  def self.unscoped?
    !!unscoped
  end

  def self.default_tenant
    @default_tenant unless unscoped
  end

  def self.mutable_tenant!(toggle)
    @@mutable_tenant = toggle
  end

  def self.mutable_tenant?
    @@mutable_tenant
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
    old_test_tenant = test_tenant
    old_unscoped = unscoped

    self.current_tenant = nil
    self.test_tenant = nil
    self.unscoped = true
    value = block.call
    value
  ensure
    self.current_tenant = old_tenant
    self.test_tenant = old_test_tenant
    self.unscoped = old_unscoped
  end

  def self.with_mutable_tenant(&block)
    ActsAsTenant.mutable_tenant!(true)
    without_tenant(&block)
  ensure
    ActsAsTenant.mutable_tenant!(false)
  end

  def self.should_require_tenant?
    if configuration.require_tenant.respond_to?(:call)
      !!configuration.require_tenant.call
    else
      !!configuration.require_tenant
    end
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

ActiveSupport.on_load(:active_job) do |base|
  base.prepend ActsAsTenant::ActiveJobExtensions
end
