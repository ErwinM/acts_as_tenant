module ActsAsTenant
  @@tenant_klass = nil

  def self.set_tenant_klass(klass)
    @@tenant_klass = klass
  end

  def self.tenant_klass
    @@tenant_klass
  end

  def self.fkey
    "#{@@tenant_klass.to_s}_id"
  end

  def self.current_tenant=(tenant)
    RequestStore.store[:current_tenant] = tenant
  end

  def self.current_tenant
    RequestStore.store[:current_tenant]
  end

  def self.with_tenant(tenant, &block)
    if block.nil?
      raise ArgumentError, "block required"
    end

    old_tenant = self.current_tenant
    self.current_tenant = tenant
    value = block.call
    return value

  ensure
    self.current_tenant = old_tenant
  end

  module ModelExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_tenant(tenant = :account, options = {})

        ActsAsTenant.set_tenant_klass(tenant)

        unless options[:foreign_key].nil?
          fkey = options[:foreign_key]
          belongs_to tenant, :foreign_key => fkey
        else
          fkey = ActsAsTenant.fkey
          belongs_to tenant
        end

        default_scope lambda {
          if ActsAsTenant.configuration.require_tenant && ActsAsTenant.current_tenant.nil?
            raise ActsAsTenant::Errors::NoTenantSet
          end
          where("#{self.table_name}.#{fkey} = ?", ActsAsTenant.current_tenant.id)  if ActsAsTenant.current_tenant
        }

        # Add the following validations to the receiving model:
        # - new instances should have the tenant set
        # - validate that associations belong to the tenant, currently only for belongs_to
        #
        before_validation Proc.new {|m|
          if ActsAsTenant.current_tenant
            m.send "#{fkey}=".to_sym, ActsAsTenant.current_tenant.id
          end
        }, :on => :create

        reflect_on_all_associations.each do |a|
          unless a == reflect_on_association(tenant) || a.macro != :belongs_to || a.options[:polymorphic]
            association_class =  a.options[:class_name].nil? ? a.name.to_s.classify.constantize : a.options[:class_name].constantize
            validates_each a.foreign_key.to_sym do |record, attr, value|
              record.errors.add attr, "association is invalid [ActsAsTenant]" unless value.nil? || association_class.where(:id => value).present?
            end
          end
        end

        # Dynamically generate the following methods:
        # - Rewrite the accessors to make tenant immutable
        # - Add an override to prevent unnecessary db hits
        # - Add a helper method to verify if a model has been scoped by AaT
        #
        define_method "#{fkey}=" do |integer|
          raise ActsAsTenant::Errors::TenantIsImmutable unless new_record? || send(fkey).nil?
          write_attribute("#{fkey}", integer)
        end

        define_method "#{ActsAsTenant.tenant_klass.to_s}=" do |model|
          raise ActsAsTenant::Errors::TenantIsImmutable unless new_record? || send(fkey).nil?
          super(model)
        end

        define_method "#{ActsAsTenant.tenant_klass.to_s}" do
          return ActsAsTenant.current_tenant if !ActsAsTenant.current_tenant.nil? && send(fkey) == ActsAsTenant.current_tenant.id
          super()
        end

        def scoped_by_tenant?
          true
        end
      end

      def validates_uniqueness_to_tenant(fields, args ={})
        raise ActsAsTenant::Errors::ModelNotScopedByTenant unless respond_to?(:scoped_by_tenant?)
        fkey = reflect_on_association(ActsAsTenant.tenant_klass).foreign_key
        #tenant_id = lambda { "#{ActsAsTenant.fkey}"}.call
        if args[:scope]
          args[:scope] = Array(args[:scope]) << fkey
        else
          args[:scope] = fkey
        end

        validates_uniqueness_of(fields, args)
      end
    end
  end
end
