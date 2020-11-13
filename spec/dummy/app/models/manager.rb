class Manager < ActiveRecord::Base
  belongs_to :project
  acts_as_tenant :account
end
