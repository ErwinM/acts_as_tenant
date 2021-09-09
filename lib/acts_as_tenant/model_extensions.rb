module ActsAsTenant
  module ModelExtensions
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_tenant(tenant = :account, **options)
        ActsAsTenant.set_tenant_klass(tenant)

        ActsAsTenant.add_global_record_model(self) if options[:has_global_records]

        # Create the association
        valid_options = options.slice(:foreign_key, :class_name, :inverse_of, :optional, :primary_key, :counter_cache)
        fkey = valid_options[:foreign_key] || ActsAsTenant.fkey
        pkey = valid_options[:primary_key] || ActsAsTenant.pkey
        polymorphic_type = valid_options[:foreign_type] || ActsAsTenant.polymorphic_type
        belongs_to tenant, **valid_options

        default_scope lambda {
          if ActsAsTenant.configuration.require_tenant && ActsAsTenant.current_tenant.nil? && !ActsAsTenant.unscoped?
            raise ActsAsTenant::Errors::NoTenantSet
          end

          if ActsAsTenant.current_tenant
            keys = [ActsAsTenant.current_tenant.send(pkey)].compact
            keys.push(nil) if options[:has_global_records]

            query_criteria = {fkey.to_sym => keys}
            query_criteria[polymorphic_type.to_sym] = ActsAsTenant.current_tenant.class.to_s if options[:polymorphic]
            where(query_criteria)
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
              m.send("#{fkey}=".to_sym, ActsAsTenant.current_tenant.class.to_s) if m.send(fkey.to_s).nil?
              m.send("#{polymorphic_type}=".to_sym, ActsAsTenant.current_tenant.class.to_s) if m.send(polymorphic_type.to_s).nil?
            else
              m.send "#{fkey}=".to_sym, ActsAsTenant.current_tenant.send(pkey)
            end
          end
        }, on: :create

        polymorphic_foreign_keys = reflect_on_all_associations(:belongs_to).select { |a|
          a.options[:polymorphic]
        }.map { |a| a.foreign_key }

        reflect_on_all_associations(:belongs_to).each do |a|
          unless a == reflect_on_association(tenant) || polymorphic_foreign_keys.include?(a.foreign_key)
            validates_each a.foreign_key.to_sym do |record, attr, value|
              primary_key = if a.respond_to?(:active_record_primary_key)
                a.active_record_primary_key
              else
                a.primary_key
              end.to_sym
              record.errors.add attr, "association is invalid [ActsAsTenant]" unless value.nil? || a.klass.where(primary_key => value).any?
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
            raise ActsAsTenant::Errors::TenantIsImmutable if send("#{fkey}_changed?") && persisted? && !send("#{fkey}_was").nil?
            integer
          end

          define_method "#{ActsAsTenant.tenant_klass}=" do |model|
            super(model)
            raise ActsAsTenant::Errors::TenantIsImmutable if send("#{fkey}_changed?") && persisted? && !send("#{fkey}_was").nil?
            model
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

        validation_args = args.clone
        validation_args[:scope] = if args[:scope]
          Array(args[:scope]) << fkey
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
