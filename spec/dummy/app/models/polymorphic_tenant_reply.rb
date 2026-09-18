class PolymorphicTenantReply < ActiveRecord::Base
  belongs_to :polymorphic_tenant_comment
  acts_as_tenant :polymorphic_tenant_commentable, polymorphic: true
end
