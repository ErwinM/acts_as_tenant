class Account < ActiveRecord::Base
  has_many :projects
  has_many :global_projects
  has_many :users_accounts
  has_many :users, through: :users_accounts

  default_scope -> { where(deleted_at: nil) }
end
