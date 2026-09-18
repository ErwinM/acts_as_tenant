class LateAssociationTask < ActiveRecord::Base
  self.table_name = "tasks"
  acts_as_tenant :account
  belongs_to :project
end
