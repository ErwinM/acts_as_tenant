class GlobalProjectWithConditions < ActiveRecord::Base
  self.table_name = "projects"

  acts_as_tenant :account, has_global_records: true
  validates_uniqueness_to_tenant :name, conditions: -> { where(name: "foo") }
end
