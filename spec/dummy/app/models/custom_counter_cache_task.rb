class CustomCounterCacheTask < ActiveRecord::Base
  self.table_name = "projects"
  acts_as_tenant(:account, counter_cache: "projects_count")
end
