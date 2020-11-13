class PolymorphicTenantComment < ActiveRecord::Base
  belongs_to :polymorphic_tenant_commentable, polymorphic: true
  belongs_to :account
  acts_as_tenant :polymorphic_tenant_commentable, polymorphic: true
end
