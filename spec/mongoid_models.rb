class Account
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  field :subdomain, type: String
  field :domain, type: String
  has_many :projects
end

class Project
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  has_one :manager
  has_many :tasks
  acts_as_tenant :account

  validates_uniqueness_to_tenant :name
end

class Manager
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  belongs_to :project
  acts_as_tenant :account
end

class Task
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  field :completed, type: Boolean
  belongs_to :project
  default_scope -> { where(:completed => nil).order("name" => :asc) }

  acts_as_tenant :account
  validates_uniqueness_of :name
end

class UnscopedModel
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  validates_uniqueness_of :name
end

class AliasedTask
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  acts_as_tenant(:account)
  belongs_to :project_alias, :class_name => "Project"
end

class UniqueTask
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  field :user_defined_scope, type: String
  acts_as_tenant(:account)
  belongs_to :project
  validates_uniqueness_to_tenant :name, scope: :user_defined_scope
end

class CustomForeignKeyTask
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  field :name, type: String
  field :accountID, type: Integer
  acts_as_tenant(:account, :foreign_key => "accountID")
  validates_uniqueness_to_tenant :name
end

class Comment
  include Mongoid::Document
  include ActsAsTenant::ModelExtensions
  belongs_to :commentable, polymorphic: true
  belongs_to :task, foreign_key: 'commentable_id'
  acts_as_tenant :account
end
