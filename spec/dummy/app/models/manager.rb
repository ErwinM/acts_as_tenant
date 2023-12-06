class Manager < ActiveRecord::Base
  belongs_to :project, -> { unscope(where: :deleted_at) }
  acts_as_tenant :account, -> { unscope(where: :deleted_at) }
end
