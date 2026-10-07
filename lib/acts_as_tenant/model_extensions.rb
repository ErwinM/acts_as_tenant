module ActsAsTenant
  module ModelExtensions
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_tenant(tenant = :account, scope = nil, **options)
        ActsAsTenant.set_tenant_klass(tenant)

        ActsAsTenant.add_global_record_model(self) if options[:has_global_records]

        # Create the association
        valid_options = options.slice(:foreign_key, :class_name, :inverse_of, :optional, :primary_key, :counter_cache, :polymorphic, :touch)
        pkey = valid_options[:primary_key] || ActsAsTenant.pkey
        belongs_to tenant, scope, **valid_options

        tenant_reflection = reflect_on_association(tenant)
        fkey = tenant_reflection.foreign_key.to_sym
        polymorphic_type = tenant_reflection.foreign_type&.to_sym

        # Polymorphic tenants are stored with polymorphic_name, like Rails does. Records saved before
        # that used the class name, which differs for STI tenants, so match both when scoping.
        # An OR is used because Rails 6.0 would assign an IN condition to new records as their type.
        polymorphic_condition = lambda do |current_tenant|
          polymorphic_name = current_tenant.class.polymorphic_name
          class_name = current_tenant.class.name

          if polymorphic_name == class_name
            {polymorphic_type => polymorphic_name}
          else
            arel_table[polymorphic_type].eq(polymorphic_name).or(arel_table[polymorphic_type].eq(class_name))
          end
        end

        default_scope lambda {
          current_tenant = ActsAsTenant.current_tenant

          if current_tenant
            keys = [current_tenant.public_send(pkey)].compact
            keys.push(nil) if options[:has_global_records]

            relation = if options[:through]
              joins(options[:through]).where(options[:through] => {fkey => keys})
            else
              where(fkey => keys)
            end

            options[:polymorphic] ? relation.where(polymorphic_condition.call(current_tenant)) : relation
          elsif !ActsAsTenant.unscoped? && ActsAsTenant.should_require_tenant?(self)
            raise ActsAsTenant::Errors::NoTenantSet
          else
            all
          end
        }

        # Add the following validations to the receiving model:
        # - new instances should have the tenant set
        # - validate that associations belong to the tenant, currently only for belongs_to
        #
        # New records without a tenant get the current tenant. A record assigned to
        # another tenant keeps it and fails the validation below.
        before_validation proc { |m|
          if (current_tenant = ActsAsTenant.current_tenant)
            m.public_send(:"#{fkey}=", current_tenant.public_send(pkey)) if m.public_send(fkey).nil?
            m.public_send(:"#{polymorphic_type}=", current_tenant.class.polymorphic_name) if options[:polymorphic] && m.public_send(polymorphic_type).nil?
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
            [id.to_s, type]
          end
        end

        # Compared directly since the lookup scope may not filter by tenant.
        # Records without a tenant, such as global records, are compared with the current tenant.
        tenant_mismatch = lambda do |record, associated|
          if associated.class.respond_to?(:scoped_by_tenant?)
            current_tenant = ActsAsTenant.current_tenant
            record_tenant = tenant_identity.call(record)
            record_tenant ||= [current_tenant.public_send(pkey).to_s, current_tenant.class.polymorphic_name] if current_tenant
            associated_tenant = tenant_identity.call(associated)

            record_tenant && associated_tenant && record_tenant != associated_tenant
          end
        end

        # Records must belong to the current tenant, matching what the default scope would find
        validate do |record|
          current_tenant = ActsAsTenant.current_tenant
          next unless current_tenant

          tenant_attributes = [fkey, polymorphic_type].compact
          next unless record.new_record? || tenant_attributes.any? { |attr| record.will_save_change_to_attribute?(attr) }

          record_tenant = tenant_identity.call(record)
          next if record_tenant.nil?

          record_id, record_type = record_tenant
          matches = record_id.to_s == current_tenant.public_send(pkey).to_s
          matches &&= record_type == current_tenant.class.polymorphic_name if options[:polymorphic]

          record.errors.add(fkey, :"acts_as_tenant.tenant_mismatch") unless matches
        end

        # Associations are looked up at validation time so belongs_to associations
        # declared after acts_as_tenant are validated too
        validate do |record|
          associations = record.class.reflect_on_all_associations(:belongs_to)
          polymorphic_foreign_keys = associations.select(&:polymorphic?).map(&:foreign_key)

          associations.each do |association|
            next if association.name == tenant.to_sym

            attrs = Array(association.foreign_key).map(&:to_sym)
            key_changed = attrs.any? { |attr| record.will_save_change_to_attribute?(attr) }

            if association.polymorphic?
              next unless key_changed || record.will_save_change_to_attribute?(association.foreign_type)
            else
              # Associations sharing a polymorphic foreign key are checked through the polymorphic association
              next if polymorphic_foreign_keys.include?(association.foreign_key)
              next unless key_changed
            end

            values = attrs.map { |attr| record.read_attribute_for_validation(attr) }
            next if values.any?(&:nil?)

            next unless record.validate_tenant_association?(association)

            klass = if association.polymorphic?
              type = record.read_attribute(association.foreign_type)&.safe_constantize
              type if type.is_a?(Class) && type < ActiveRecord::Base
            else
              # Raises for composite keys whose column counts don't match, like loading the association would
              association.check_validity! if attrs.size > 1
              association.klass
            end

            associated = if klass
              relation = association.scope ? association.scope_for(klass.all, record) : klass.all
              relation = klass.tenant_validation_scope(relation)
              relation.find_by(Array(association.association_primary_key(klass)).zip(values).to_h)
            end

            if associated.nil? || tenant_mismatch.call(record, associated)
              # Composite keys often include the tenant column, which is not the one to blame
              error_attr = (attrs - [fkey]).first || attrs.first
              record.errors.add(error_attr, :"acts_as_tenant.association_invalid")
            end
          end
        end

        # Tenant writers raise if the tenant changes on a persisted record
        to_include = Module.new {
          define_method :"#{fkey}=" do |integer|
            write_attribute(fkey, integer)
            raise_if_tenant_changed
            integer
          end

          define_method :"#{tenant}=" do |model|
            super(model)
            raise_if_tenant_changed
            model
          end

          define_method :raise_if_tenant_changed do
            raise ActsAsTenant::Errors::TenantIsImmutable if !ActsAsTenant.mutable_tenant? && tenant_modified?
          end
          private :raise_if_tenant_changed

          define_method :tenant_modified? do
            will_save_change_to_attribute?(fkey) && persisted? && attribute_in_database(fkey).present?
          end
        }
        include to_include

        # Stored per model since ActsAsTenant.tenant_klass is whichever model called acts_as_tenant last
        class_attribute :acts_as_tenant_foreign_key, instance_accessor: false
        self.acts_as_tenant_foreign_key = fkey

        class << self
          def scoped_by_tenant?
            true
          end
        end
      end

      # The relation used to find associated records when validating belongs_to associations.
      # Override to change the lookup for all associations to this model, for example to include soft-deleted records.
      def tenant_validation_scope(relation)
        relation
      end

      def validates_uniqueness_to_tenant(*fields)
        args = fields.extract_options!
        raise ActsAsTenant::Errors::ModelNotScopedByTenant unless respond_to?(:scoped_by_tenant?)

        fkey = acts_as_tenant_foreign_key

        validation_args = args.deep_dup
        validation_args[:scope] = if args[:scope]
          Array(args[:scope]) + [fkey]
        else
          fkey
        end

        # validating within tenant scope
        validates_uniqueness_of(*fields, validation_args)

        if ActsAsTenant.models_with_global_records.include?(self)
          arg_if = args.delete(:if)
          arg_condition = args.delete(:conditions)
          arg_if_passes = ->(instance) { arg_if.blank? || arg_if.call(instance) }

          # if tenant is not set (instance is global) - validating globally
          global_validation_args = args.merge(
            if: ->(instance) { instance[fkey].blank? && arg_if_passes.call(instance) }
          )
          validates_uniqueness_of(*fields, global_validation_args)

          # if tenant is set (instance is not global) and records can be global - validating within records with blank tenant
          blank_tenant_validation_args = args.merge(
            conditions: -> { arg_condition.blank? ? where(fkey => nil) : arg_condition.call.where(fkey => nil) },
            if: ->(instance) { instance[fkey].present? && arg_if_passes.call(instance) }
          )

          validates_uniqueness_of(*fields, blank_tenant_validation_args)
        end
      end
    end

    # Override to skip the tenant validation of a belongs_to association
    def validate_tenant_association?(reflection)
      true
    end
  end
end
