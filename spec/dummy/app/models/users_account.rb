class UsersAccount < ActiveRecord::Base
  acts_as_tenant :account
  belongs_to :user

  acts_as_tenant :org_account, class_name: "Account", foreign_key: :account_id
  belongs_to :org_user, class_name: "User", foreign_key: :user_id
end
