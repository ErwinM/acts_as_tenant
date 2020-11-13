# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 1) do
  create_table :accounts, force: true do |t|
    t.column :name, :string
    t.column :subdomain, :string
    t.column :domain, :string
    t.column :projects_count, :integer, default: 0
  end

  create_table :projects, force: true do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

  create_table :managers, force: true do |t|
    t.column :name, :string
    t.column :project_id, :integer
    t.column :account_id, :integer
  end

  create_table :tasks, force: true do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :project_id, :integer
    t.column :completed, :boolean
  end

  create_table :countries, force: true do |t|
    t.column :name, :string
  end

  create_table :unscoped_models, force: true do |t|
    t.column :name, :string
  end

  create_table :aliased_tasks, force: true do |t|
    t.column :name, :string
    t.column :project_alias_id, :integer
    t.column :account_id, :integer
  end

  create_table :unique_tasks, force: true do |t|
    t.column :name, :string
    t.column :user_defined_scope, :string
    t.column :project_id, :integer
    t.column :account_id, :integer
  end

  create_table :custom_foreign_key_tasks, force: true do |t|
    t.column :name, :string
    t.column :accountID, :integer
  end

  create_table :custom_primary_key_tasks, force: true do |t|
    t.column :name, :string
  end

  create_table :articles, force: true do |t|
    t.column :title, :string
  end

  create_table :comments, force: true do |t|
    t.column :commentable_id, :integer
    t.column :commentable_type, :string
    t.column :account_id, :integer
  end

  create_table :polymorphic_tenant_comments, force: true do |t|
    t.column :polymorphic_tenant_commentable_id, :integer
    t.column :polymorphic_tenant_commentable_type, :string
    t.column :account_id, :integer
  end
end
