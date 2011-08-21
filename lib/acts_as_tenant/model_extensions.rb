# ActsAsTenant


module ActsAsTenant
  
  class << self
    cattr_accessor :tenant_class
    attr_accessor :current_tenant
  end
  
  module ModelExtensions
    extend ActiveSupport::Concern
  
    # Alias the v_uniqueness_of method so we can scope it to the current tenant when relevant
    included do
      class << self
        alias original_validates_uniqueness_of :validates_uniqueness_of unless method_defined?(:original_validates_uniqueness_of)
        alias validates_uniqueness_of :scoped_validates_uniqueness_of
      end
    end
  
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
          m.send "#{association}=".to_sym, ActsAsTenant.current_tenant
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
            raise "#{fkey} is immutable!"
          end  
        end
      
        define_method "#{association}=" do |model|  
          if new_record?
            write_attribute(association, model)  
          else
            raise "#{association} is immutable!"
          end  
        end
      
        # add validation of associations against tenant scope
        reflect_on_all_associations.each do |a|
          unless a == reflection || a.macro == :has_many
            validates_each a.foreign_key.to_sym do |record, attr, value|
              record.errors.add attr, "is invalid" unless a.name.to_s.classify.constantize.where(:id => value).present?
            end
          end
        end 
      end
    
      private
       def scoped_validates_uniqueness_of(fields, args = {})
         if respond_to?(:is_scoped_by_tenant?)
           raise "ActsAsTenant: :scope argument of uniqueness validator is not available for classes that are scoped by acts_as_tenant" if args.has_key?(:scope)
           args[:scope] = lambda { "#{ActsAsTenant.tenant_class.to_s.downcase}_id"}.call
           puts "#{ActsAsTenant.tenant_class.to_s.downcase}_id"
         end
         ret = original_validates_uniqueness_of(fields, args)
       end
  
    end
  end
end
