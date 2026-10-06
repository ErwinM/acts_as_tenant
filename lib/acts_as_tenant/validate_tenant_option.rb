module ActsAsTenant
  # Adds the validate_tenant option to belongs_to
  module ValidateTenantOption
    def self.valid_options
      [:validate_tenant]
    end

    def self.build(model, reflection)
      if reflection.options.key?(:validate_tenant) && !reflection.belongs_to?
        raise ArgumentError, "validate_tenant is only supported on belongs_to associations"
      end
    end
  end
end
