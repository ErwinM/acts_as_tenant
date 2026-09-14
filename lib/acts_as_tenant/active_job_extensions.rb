module ActsAsTenant
  module ActiveJobExtensions
    attr_reader :tenant_global_id

    def serialize
      super.merge("current_tenant" => ActsAsTenant.current_tenant&.to_global_id&.to_s)
    end

    def deserialize(job_data)
      @tenant_global_id = job_data.delete("current_tenant")
      super
    end

    def perform_now
      return super if tenant_global_id.nil?

      ActsAsTenant.with_tenant(GlobalID::Locator.locate(tenant_global_id)) { super }
    end
  end
end
