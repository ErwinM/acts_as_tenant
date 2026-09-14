class AliasedTask < ActiveRecord::Base
  belongs_to :project_alias, class_name: "Project"
  acts_as_tenant(:account)
end
