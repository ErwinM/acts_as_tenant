class UsersAccount < ActiveRecord::Base
  belongs_to :user
  acts_as_tenant :account
end
