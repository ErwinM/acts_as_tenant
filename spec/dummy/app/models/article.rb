class Article < ActiveRecord::Base
  has_many :polymorphic_tenant_comments, as: :polymorphic_tenant_commentable
end
