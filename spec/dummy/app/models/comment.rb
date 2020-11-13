class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true
  belongs_to :task, -> { where(comments: {commentable_type: "Task"}) }, foreign_key: "commentable_id"
  acts_as_tenant :account
end
