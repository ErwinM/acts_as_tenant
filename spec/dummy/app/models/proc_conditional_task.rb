class ProcConditionalTask < ActiveRecord::Base
  self.table_name = "tasks"
  acts_as_tenant :account
  belongs_to :project, validate_tenant: -> { name != "skip" }
end
