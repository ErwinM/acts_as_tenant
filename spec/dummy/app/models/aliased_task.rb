class AliasedTask < ActiveRecord::Base
  acts_as_tenant(:account)
  belongs_to :project_alias, class_name: "Project"
end
