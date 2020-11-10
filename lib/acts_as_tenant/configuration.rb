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
    attr_writer :require_tenant, :pkey

    def require_tenant
      @require_tenant ||= false
    end

    def pkey
      @pkey ||= :id
    end
  end
end
