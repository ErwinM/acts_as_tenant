class MultiFieldUniqueTask < ActiveRecord::Base
  self.table_name = "unique_tasks"
  acts_as_tenant(:account)
  validates_uniqueness_to_tenant :name, :user_defined_scope
end
