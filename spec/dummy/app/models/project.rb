class Project < ActiveRecord::Base
  has_one :manager
  has_many :tasks
  has_many :polymorphic_tenant_comments, as: :polymorphic_tenant_commentable
  acts_as_tenant :account

  validates_uniqueness_to_tenant :name
end
