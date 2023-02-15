class User < ActiveRecord::Base
  has_many :users_accounts
  acts_as_tenant :accounts, through: :users_accounts

  has_many :org_users_accounts, class_name: "UsersAccount", inverse_of: :org_user
  acts_as_tenant :organizations, through: :org_users_accounts, source: :org_account, class_name: "Account", foreign_key: :account_id
end
