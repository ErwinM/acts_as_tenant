module ActsAsTenant
  module ActiveJobExtensions
    def serialize
      super.merge("current_tenant" => ActsAsTenant.current_tenant&.to_global_id&.to_s)
    end

    def deserialize(job_data)
      tenant_global_id = job_data.delete("current_tenant")
      ActsAsTenant.current_tenant = tenant_global_id ? GlobalID::Locator.locate(tenant_global_id) : nil
      super
    end
  end
end
