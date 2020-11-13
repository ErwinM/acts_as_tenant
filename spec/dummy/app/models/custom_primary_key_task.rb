class CustomPrimaryKeyTask < ActiveRecord::Base
  acts_as_tenant(:account, foreign_key: "name", primary_key: "name")
  validates_presence_of :name
end
