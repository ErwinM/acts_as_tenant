class UniqueTask < ActiveRecord::Base
  belongs_to :project
  acts_as_tenant(:account)
  validates_uniqueness_to_tenant :name, scope: :user_defined_scope
end
