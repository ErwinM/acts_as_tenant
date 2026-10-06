class ConditionalTask < ActiveRecord::Base
  self.table_name = "tasks"
  acts_as_tenant :account
  belongs_to :project, validate_tenant: :validate_project?

  attr_accessor :validate_project

  def validate_project?
    validate_project
  end
end
