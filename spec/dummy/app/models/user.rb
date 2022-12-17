class User < ActiveRecord::Base
  has_many :users_accounts
  has_many :accounts, through: :users_accounts

  acts_as_tenant :account, through: :users_accounts
end
