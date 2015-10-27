module ActsAsTenant
  @@configuration = nil

  def self.configure
    @@configuration = Configuration.new

    if block_given?
      yield configuration
    end

    configuration
  end

  def self.configuration
    @@configuration || configure
  end

  class Configuration
    attr_writer :require_tenant, :allow_fallback

    def require_tenant
      @require_tenant ||= false
    end

    def allow_fallback
      @allow_fallback ||= false
    end
  end
end
