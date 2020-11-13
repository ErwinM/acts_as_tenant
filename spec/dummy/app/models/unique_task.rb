class UniqueTask < ActiveRecord::Base
  acts_as_tenant(:account)
  belongs_to :project
  validates_uniqueness_to_tenant :name, scope: :user_defined_scope
end
