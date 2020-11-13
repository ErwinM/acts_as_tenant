class Task < ActiveRecord::Base
  belongs_to :project
  default_scope -> { where(completed: nil).order("name") }

  acts_as_tenant :account
  validates_uniqueness_of :name
end
