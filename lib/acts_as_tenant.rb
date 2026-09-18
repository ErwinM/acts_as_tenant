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

  class Current < ActiveSupport::CurrentAttributes
    attribute :current_tenant, :acts_as_tenant_unscoped, :acts_as_tenant_mutable

    # Rails resets attributes directly at the end of a request or job, bypassing the writer below
    resets { ActsAsTenant.configuration.tenant_change_hook&.call(nil) }

    def current_tenant=(tenant)
      super.tap { ActsAsTenant.configuration.tenant_change_hook&.call(tenant) }
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
    Current.acts_as_tenant_mutable = toggle
  end

  def self.mutable_tenant?
    !!Current.acts_as_tenant_mutable
  end

  def self.with_tenant(tenant, &block)
    raise ArgumentError, "block required" if block.nil?

    Current.set(current_tenant: tenant, &block)
  end

  def self.without_tenant(&block)
    raise ArgumentError, "block required" if block.nil?

    old_test_tenant = test_tenant
    self.test_tenant = nil
    begin
      Current.set(current_tenant: nil, acts_as_tenant_unscoped: true, &block)
    ensure
      self.test_tenant = old_test_tenant
    end
  end

  def self.with_mutable_tenant(&block)
    Current.set(acts_as_tenant_mutable: true) { without_tenant(&block) }
  end

  def self.should_require_tenant?(relation = nil)
    config = configuration.require_tenant
    return !!config unless config.respond_to?(:call)

    arity = config.respond_to?(:arity) ? config.arity : config.method(:call).arity
    arity.zero? ? !!config.call : !!config.call(relation)
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
