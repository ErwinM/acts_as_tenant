class CustomForeignKeyTask < ActiveRecord::Base
  acts_as_tenant(:account, foreign_key: "accountID")
  validates_uniqueness_to_tenant :name
end
