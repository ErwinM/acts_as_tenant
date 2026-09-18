module ActsAsTenant
  module ModelExtensions
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_tenant(tenant = :account, scope = nil, **options)
        ActsAsTenant.set_tenant_klass(tenant)

        ActsAsTenant.add_global_record_model(self) if options[:has_global_records]

        # Create the association
        valid_options = options.slice(:foreign_key, :class_name, :inverse_of, :optional, :primary_key, :counter_cache, :polymorphic, :touch)
        fkey = valid_options[:foreign_key] || ActsAsTenant.fkey
        pkey = valid_options[:primary_key] || ActsAsTenant.pkey
        polymorphic_type = valid_options[:foreign_type] || ActsAsTenant.polymorphic_type
        belongs_to tenant, scope, **valid_options

        # Polymorphic tenants are stored with polymorphic_name, like Rails does. Records saved before
        # that used the class name, which differs for STI tenants, so match both when scoping.
        # An OR is used because Rails 6.0 would assign an IN condition to new records as their type.
        polymorphic_condition = lambda do |table|
          polymorphic_name = ActsAsTenant.current_tenant.class.polymorphic_name
          class_name = ActsAsTenant.current_tenant.class.name

          if polymorphic_name == class_name
            {polymorphic_type.to_sym => polymorphic_name}
          else
            table[polymorphic_type].eq(polymorphic_name).or(table[polymorphic_type].eq(class_name))
          end
        end

        default_scope lambda {
          if ActsAsTenant.should_require_tenant?(self) && ActsAsTenant.current_tenant.nil? && !ActsAsTenant.unscoped?
            raise ActsAsTenant::Errors::NoTenantSet
          end

          if ActsAsTenant.current_tenant
            keys = [ActsAsTenant.current_tenant.send(pkey)].compact
            keys.push(nil) if options[:has_global_records]

            relation = if options[:through]
              joins(options[:through]).where(options[:through] => {fkey.to_sym => keys})
            else
              where(fkey.to_sym => keys)
            end

            options[:polymorphic] ? relation.where(polymorphic_condition.call(arel_table)) : relation
          else
            all
          end
        }

        # Add the following validations to the receiving model:
        # - new instances should have the tenant set
        # - validate that associations belong to the tenant, currently only for belongs_to
        #
        before_validation proc { |m|
          if ActsAsTenant.current_tenant
            if options[:polymorphic]
              m.send(:"#{fkey}=", ActsAsTenant.current_tenant.send(pkey)) if m.send(fkey.to_s).nil?
              m.send(:"#{polymorphic_type}=", ActsAsTenant.current_tenant.class.polymorphic_name) if m.send(polymorphic_type.to_s).nil?
            else
              m.send :"#{fkey}=", ActsAsTenant.current_tenant.send(pkey)
            end
          end
        }, on: :create

        # Returns [tenant id, tenant class] for a record, or nil if it has no tenant.
        # Classes are normalized with polymorphic_name so STI tenants compare equal.
        tenant_identity = lambda do |model|
          reflection = model.class.reflect_on_association(tenant)
          id = model.read_attribute(reflection.foreign_key) if reflection

          if id
            type = if reflection.polymorphic?
              stored_type = model.read_attribute(reflection.foreign_type)
              stored_type&.safe_constantize&.polymorphic_name || stored_type
            else
              reflection.klass.polymorphic_name
            end
            [id, type]
          end
        end

        # Without a current tenant the association lookup isn't scoped, so compare the tenants directly
        tenant_mismatch = lambda do |record, associated|
          if ActsAsTenant.current_tenant.nil? && associated.class.respond_to?(:scoped_by_tenant?)
            record_tenant = tenant_identity.call(record)
            associated_tenant = tenant_identity.call(associated)

            record_tenant && associated_tenant && record_tenant != associated_tenant
          end
        end

        # Associations are looked up at validation time so belongs_to associations
        # declared after acts_as_tenant are validated too
        validate do |record|
          associations = record.class.reflect_on_all_associations(:belongs_to)
          polymorphic_foreign_keys = associations.select { |a| a.options[:polymorphic] }.map(&:foreign_key)

          associations.each do |a|
            next if a.name == tenant.to_sym || polymorphic_foreign_keys.include?(a.foreign_key)

            attr = a.foreign_key.to_sym
            value = record.read_attribute_for_validation(attr)
            next if value.nil?
            next unless record.will_save_change_to_attribute?(attr)

            primary_key = if a.respond_to?(:active_record_primary_key)
              a.active_record_primary_key
            else
              a.primary_key
            end.to_sym
            scope = a.scope || ->(relation) { relation }
            associated = a.klass.class_eval(&scope).find_by(primary_key => value)

            if associated.nil? || tenant_mismatch.call(record, associated)
              record.errors.add attr, "association is invalid [ActsAsTenant]"
            end
          end
        end

        # Dynamically generate the following methods:
        # - Rewrite the accessors to make tenant immutable
        # - Add an override to prevent unnecessary db hits
        # - Add a helper method to verify if a model has been scoped by AaT
        to_include = Module.new {
          define_method "#{fkey}=" do |integer|
            write_attribute(fkey.to_s, integer)
            raise ActsAsTenant::Errors::TenantIsImmutable if !ActsAsTenant.mutable_tenant? && tenant_modified?
            integer
          end

          define_method "#{ActsAsTenant.tenant_klass}=" do |model|
            super(model)
            raise ActsAsTenant::Errors::TenantIsImmutable if !ActsAsTenant.mutable_tenant? && tenant_modified?
            model
          end

          define_method :tenant_modified? do
            will_save_change_to_attribute?(fkey) && persisted? && attribute_in_database(fkey).present?
          end
        }
        include to_include

        class << self
          def scoped_by_tenant?
            true
          end
        end
      end

      def validates_uniqueness_to_tenant(fields, args = {})
        raise ActsAsTenant::Errors::ModelNotScopedByTenant unless respond_to?(:scoped_by_tenant?)

        fkey = reflect_on_association(ActsAsTenant.tenant_klass).foreign_key

        validation_args = args.deep_dup
        validation_args[:scope] = if args[:scope]
          Array(args[:scope]) + [fkey]
        else
          fkey
        end

        # validating within tenant scope
        validates_uniqueness_of(fields, validation_args)

        if ActsAsTenant.models_with_global_records.include?(self)
          arg_if = args.delete(:if)
          arg_condition = args.delete(:conditions)

          # if tenant is not set (instance is global) - validating globally
          global_validation_args = args.merge(
            if: ->(instance) { instance[fkey].blank? && (arg_if.blank? || arg_if.call(instance)) }
          )
          validates_uniqueness_of(fields, global_validation_args)

          # if tenant is set (instance is not global) and records can be global - validating within records with blank tenant
          blank_tenant_validation_args = args.merge({
            conditions: -> { arg_condition.blank? ? where(fkey => nil) : arg_condition.call.where(fkey => nil) },
            if: ->(instance) { instance[fkey].present? && (arg_if.blank? || arg_if.call(instance)) }
          })

          validates_uniqueness_of(fields, blank_tenant_validation_args)
        end
      end
    end
  end
end
