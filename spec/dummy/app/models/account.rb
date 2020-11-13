class Account < ActiveRecord::Base
  has_many :projects
  has_many :global_projects
end
