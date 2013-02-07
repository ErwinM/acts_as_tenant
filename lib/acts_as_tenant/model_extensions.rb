# ActsAsTenant


module ActsAsTenant
  
  class << self
    cattr_accessor :tenant_class

    # This will also work whithin Fibers:
    # http://devblog.avdi.org/2012/02/02/ruby-thread-locals-are-also-fiber-local/
    def current_tenant=(tenant)
      Thread.current[:current_tenant] = tenant
    end

    def current_tenant
      Thread.current[:current_tenant]
    end

    # Sets the current_tenant within the given block
    def with_tenant(tenant, &block)
      if block.nil?
        raise ArgumentError, "block required"
      end

      old_tenant = self.current_tenant
      self.current_tenant = tenant

      value = block.call

      self.current_tenant= old_tenant
      return value
    end
  end
  
  module ModelExtensions
    extend ActiveSupport::Concern
  
    # Alias the v_uniqueness_of method so we can scope it to the current tenant when relevant
  
    module ClassMethods
    
      def acts_as_tenant(association = :account)
        
        # Method that enables checking if a class is scoped by tenant
        def self.is_scoped_by_tenant?
          true
        end
        
        ActsAsTenant.tenant_class ||= association
        
        # Setup the association between the class and the tenant class
        belongs_to association
      
        # get the tenant model and its foreign key
        reflection = reflect_on_association association
        
        # As the "foreign_key" method changed name in 3.1 we check for backward compatibility 
        if reflection.respond_to?(:foreign_key)
          fkey = reflection.foreign_key
        else
          fkey = reflection.association_foreign_key
        end
    
        # set the current_tenant on newly created objects
        before_validation Proc.new {|m|
          return unless ActsAsTenant.current_tenant
          m.send "#{association}_id=".to_sym, ActsAsTenant.current_tenant.id
        }, :on => :create
    
        # set the default_scope to scope to current tenant
        default_scope lambda {
          where({fkey => ActsAsTenant.current_tenant.id}) if ActsAsTenant.current_tenant
        }
    
        # Rewrite accessors to make tenant foreign_key/association immutable
        define_method "#{fkey}=" do |integer|  
          if new_record?
            write_attribute(fkey, integer)  
          else
            raise "#{fkey} is immutable! [ActsAsTenant]"
          end  
        end
      
        define_method "#{association}=" do |model|  
          if new_record?
            super(model) 
          else
            raise "#{association} is immutable! [ActsAsTenant]"
          end  
        end
      
        # add validation of associations against tenant scope
        # we can't do this for polymorphic associations so we 
        # exempt them
        reflect_on_all_associations.each do |a|
          unless a == reflection || a.macro == :has_many || a.macro == :has_one || a.macro == :has_and_belongs_to_many || a.options[:polymorphic]
            # check if the association is aliasing another class, if so 
            # find the unaliased class name
            association_class =  a.options[:class_name].nil? ? a.name.to_s.classify.constantize : a.options[:class_name].constantize
            validates_each a.foreign_key.to_sym do |record, attr, value|
              # Invalidate the association unless the parent is known to the tenant or no association has
              # been set.
              record.errors.add attr, "is invalid [ActsAsTenant]" unless value.nil? || association_class.where(:id => value).present?
            end
          end
        end 
      end
      
      def validates_uniqueness_to_tenant(fields, args ={})
        raise "[ActsAsTenant] validates_uniqueness_to_tenant: no current tenant" unless respond_to?(:is_scoped_by_tenant?)
        tenant_id = lambda { "#{ActsAsTenant.tenant_class.to_s.downcase}_id"}.call
        args[:scope].nil? ? args[:scope] = tenant_id : args[:scope] << tenant_id
        validates_uniqueness_of(fields, args)
      end
      
    end
  end
end
