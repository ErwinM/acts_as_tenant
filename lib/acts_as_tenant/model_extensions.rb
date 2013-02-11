module ActsAsTenant

  # This will also work whithin Fibers:
  # http://devblog.avdi.org/2012/02/02/ruby-thread-locals-are-also-fiber-local/
  def self.current_tenant=(tenant)
    Thread.current[:current_tenant] = tenant
  end

  def self.current_tenant
    Thread.current[:current_tenant]
  end

  # Sets the current_tenant within the given block
  def self.with_tenant(tenant, &block)
    if block.nil?
      raise ArgumentError, "block required"
    end

    old_tenant = self.current_tenant
    self.current_tenant = tenant

    value = block.call
    self.current_tenant= old_tenant
    return value
  end

  def self.tenant_required?
    Thread.current[:tenant_required]
  end

  def self.require_tenant
    Thread.current[:tenant_required] = true
  end
  
  module ModelExtensions
    extend ActiveSupport::Concern
  
    # Alias the v_uniqueness_of method so we can scope it to the current tenant when relevant
  
    module ClassMethods
      def acts_as_tenant(association = :account)
        belongs_to association
        
        # Method that enables checking if a class is scoped by tenant
        def self.is_scoped_by_tenant?
          true
        end
        
        @tenant_klass ||= association
       
      
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
          if ActsAsTenant.tenant_required? && ActsAsTenant.current_tenant.nil?
            raise "No tenant found, while tenant_required is set to true [ActsAsTenant]"
          end
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
          unless a == reflection || a.macro == :has_many || a.macro == :has_one || a.options[:polymorphic] 
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
        tenant_id = lambda { "#{@tenant_klass.to_s.downcase}_id"}.call
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