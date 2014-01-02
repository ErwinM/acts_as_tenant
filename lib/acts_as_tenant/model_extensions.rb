module ActsAsTenant
  @@tenant_klass = {}
  
  def self.set_tenant_klass(class_name, klass)
    @@tenant_klass[class_name] = klass
  end
  
  def self.tenant_klass(class_name)
    @@tenant_klass[class_name]
  end
  
  def self.fkey(class_name)
    "#{@@tenant_klass[class_name].to_s}_id"
  end
  
  def self.current_tenant=(tenant)
    RequestStore.store[:current_tenant] = tenant
  end

  def self.current_tenant
    RequestStore.store[:current_tenant]
  end

  def self.current_tenant_klass
    RequestStore.store[:current_tenant].class.name.downcase.to_sym
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
      def acts_as_tenant(association = :account)
        belongs_to association
        class_name = self.name
        ActsAsTenant.set_tenant_klass(association)
        
        default_scope lambda {
          if ActsAsTenant.configuration.require_tenant && ActsAsTenant.current_tenant.nil?
            raise ActsAsTenant::Errors::NoTenantSet
          end
          where({ActsAsTenant.fkey(class_name) => ActsAsTenant.current_tenant.id}) if ActsAsTenant.current_tenant && ActsAsTenant.current_tenant_klass == ActsAsTenant.tenant_klass(class_name)
        }

        # Add the following validations to the receiving model:
        # - new instances should have the tenant set
        # - validate that associations belong to the tenant, currently only for belongs_to
        #
        before_validation Proc.new {|m|
          if ActsAsTenant.current_tenant && ActsAsTenant.current_tenant_klass == ActsAsTenant.tenant_klass(class_name)
            m.send "#{association}_id=".to_sym, ActsAsTenant.current_tenant.id
          end
        }, :on => :create
    
        reflect_on_all_associations.each do |a|
          unless a == reflect_on_association(association) || a.macro != :belongs_to || a.options[:polymorphic] 
            association_class =  a.options[:class_name].nil? ? a.name.to_s.classify.constantize : a.options[:class_name].constantize
            validates_each a.foreign_key.to_sym do |record, attr, value|
              record.errors.add attr, "association is invalid [ActsAsTenant]" unless value.nil? || association_class.where(:id => value).present?
            end
          end
        end
        
        # Dynamically generate the following methods:
        # - Rewrite the accessors to make tenant immutable
        # - Add a helper method to verify if a model has been scoped by AaT
        #
        define_method "#{ActsAsTenant.fkey(class_name)}=" do |integer|
          raise ActsAsTenant::Errors::TenantIsImmutable unless new_record?
          write_attribute("#{ActsAsTenant.fkey(class_name)}", integer)  
        end

        define_method "#{ActsAsTenant.tenant_klass(class_name).to_s}=" do |model|  
          raise ActsAsTenant::Errors::TenantIsImmutable unless new_record?
          super(model) 
        end
        
        def scoped_by_tenant?
          true
        end
      end
      
      def validates_uniqueness_to_tenant(fields, args ={})
        raise ActsAsTenant::Errors::ModelNotScopedByTenant unless respond_to?(:scoped_by_tenant?)
        class_name = self.name
        tenant_id = lambda { "#{ActsAsTenant.fkey(class_name)}"}.call
        if args[:scope]
          args[:scope] = Array(args[:scope]) << tenant_id
        else
          args[:scope] = tenant_id
        end
        
        validates_uniqueness_of(fields, args)
      end
    end
  end
end
