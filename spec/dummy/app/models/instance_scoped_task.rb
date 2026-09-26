class InstanceScopedTask < ActiveRecord::Base
  self.table_name = "tasks"
  acts_as_tenant :account
  belongs_to :project, ->(task) { where(name: task.name) }
end
