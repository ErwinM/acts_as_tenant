# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../spec/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../spec/dummy/db/migrate", __dir__)]
ActiveRecord::Migration.maintain_test_schema!

require "rspec/rails"

RSpec.configure do |config|
  config.after(:each) do
    ActsAsTenant.current_tenant = nil
    ActsAsTenant.test_tenant = nil
  end

  if Rails.gem_version >= Gem::Version.new("7.1")
    config.fixture_paths = ["spec/fixtures"]
  else
    config.fixture_path = "spec/fixtures"
  end
  config.global_fixtures = :all
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = true
end
