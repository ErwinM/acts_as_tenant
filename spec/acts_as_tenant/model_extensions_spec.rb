require 'spec_helper'

# Setup the db
ActiveRecord::Schema.define(:version => 1) do
  create_table :accounts, :force => true do |t|
    t.column :name, :string
    t.column :subdomain, :string
    t.column :domain, :string
  end

  create_table :projects, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

  create_table :managers, :force => true do |t|
    t.column :name, :string
    t.column :project_id, :integer
    t.column :account_id, :integer
  end

  create_table :tasks, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :project_id, :integer
    t.column :completed, :boolean
  end

  create_table :countries, :force => true do |t|
    t.column :name, :string
  end

  create_table :unscoped_models, :force => true do |t|
    t.column :name, :string
  end

  create_table :aliased_tasks, :force => true do |t|
    t.column :name, :string
    t.column :project_alias_id, :integer
    t.column :account_id, :integer
  end

  create_table :unique_tasks, :force => true do |t|
    t.column :name, :string
    t.column :user_defined_scope, :string
    t.column :project_id, :integer
    t.column :account_id, :integer
  end

  create_table :custom_foreign_key_tasks, :force => true do |t|
    t.column :name, :string
    t.column :accountID, :integer
  end

  create_table :shared_tasks, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

end

# Setup the models
class Account < ActiveRecord::Base
  has_many :projects
end

class Project < ActiveRecord::Base
  has_one :manager
  has_many :tasks
  acts_as_tenant :account

  validates_uniqueness_to_tenant :name
end

class Manager < ActiveRecord::Base
  belongs_to :project
  acts_as_tenant :account
end

class Task < ActiveRecord::Base
  belongs_to :project
  default_scope -> { where(:completed => nil).order("name") }

  acts_as_tenant :account
  validates_uniqueness_of :name
end

class UnscopedModel < ActiveRecord::Base
  validates_uniqueness_of :name
end

class AliasedTask < ActiveRecord::Base
  acts_as_tenant(:account)
  belongs_to :project_alias, :class_name => "Project"
end

class UniqueTask < ActiveRecord::Base
  acts_as_tenant(:account)
  belongs_to :project
  validates_uniqueness_to_tenant :name, scope: :user_defined_scope
end

class CustomForeignKeyTask < ActiveRecord::Base
  acts_as_tenant(:account, :foreign_key => "accountID")
  validates_uniqueness_to_tenant :name
end

class SharedTask < ActiveRecord::Base
  acts_as_tenant(:account, include_nulls: true)
end

# Start testing!
describe ActsAsTenant do
  after { ActsAsTenant.current_tenant = nil }

  # Setting and getting
  describe 'Setting the current tenant' do
    before { ActsAsTenant.current_tenant = :foo }
    it { ActsAsTenant.current_tenant == :foo }
  end

  describe 'is_scoped_as_tenant should return the correct value when true' do
    it {expect(Project.respond_to?(:scoped_by_tenant?)).to eq(true)}
  end

  describe 'is_scoped_as_tenant should return the correct value when false' do
    it {expect(UnscopedModel.respond_to?(:scoped_by_tenant?)).to eq(false)}
  end

  describe 'tenant_id should be immutable, if already set' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = @account.projects.create!(:name => 'bar')
    end

    it { expect {@project.account_id = @account.id + 1}.to raise_error }
  end

  describe 'tenant_id should be mutable, if not already set' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = Project.create!(:name => 'bar')
    end

    it { expect(@project.account_id).to be_nil }
    it { expect { @project.account = @account }.not_to raise_error }
  end

  describe 'tenant_id should auto populate after initialization' do
    before do
      @account = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = @account
    end
    it {expect(Project.new.account_id).to eq(@account.id)}
  end

  describe 'Handles custom foreign_key on tenant model' do
    before do
      @account  = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = @account
      @custom_foreign_key_task = CustomForeignKeyTask.create!(:name => 'foo')
    end

    it { expect(@custom_foreign_key_task.account).to eq(@account) }
  end

  # Scoping models
  describe 'Project.all should be scoped to the current tenant if set' do
    before do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      @project1 = @account1.projects.create!(:name => 'foobar')
      @project2 = @account2.projects.create!(:name => 'baz')

      ActsAsTenant.current_tenant= @account1
      @projects = Project.all
    end

    it { expect(@projects.length).to eq(1) }
    it { expect(@projects).to eq([@project1]) }
  end

  describe 'Project.unscoped.all should return the unscoped value' do
    before do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      @project1 = @account1.projects.create!(:name => 'foobar')
      @project2 = @account2.projects.create!(:name => 'baz')

      ActsAsTenant.current_tenant= @account1
      @projects = Project.unscoped
    end

    it { expect(@projects.count).to eq(2) }
  end

  describe 'Querying the tenant from a scoped model without a tenant set' do
    before do
      @project = Project.create!(:name => 'bar')
    end

    it { @project.account }
  end

  describe 'Querying the tenant from a scoped model with a tenant set' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = @account.projects.create!(:name => 'foobar')
      ActsAsTenant.current_tenant= @account1
    end

    it { @project.account }
  end

  # Associations
  describe 'Associations should be correctly scoped by current tenant' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = Project.create!(:name => 'foobar', :account => @account )
      # the next line should normally be (nearly) impossible: a task assigned to a tenant project,
      # but the task has no tenant assigned
      @task1 = Task.create!(:name => 'no_tenant', :project => @project)

      ActsAsTenant.current_tenant = @account
      @task2 = @project.tasks.create!(:name => 'baz')
      @tasks = @project.tasks
    end

    it 'should correctly set the tenant on the task created with current_tenant set' do
      expect(@task2.account).to eq(@account)
    end

    it 'should filter out the non-tenant task from the project' do
      expect(@tasks.length).to eq(1)
    end
  end

  describe 'Associations can only be made with in-scope objects' do
    before do
      @account = Account.create!(:name => 'foo')
      @project1 = Project.create!(:name => 'inaccessible_project', :account_id => @account.id + 1)

      ActsAsTenant.current_tenant = @account
      @project2 = Project.create!(:name => 'accessible_project')
      @task = @project2.tasks.create!(:name => 'bar')
    end

    it { expect(@task.update_attributes(:project_id => @project1.id)).to eq(false) }
  end

  describe "Create and save an AaT-enabled child without it having a parent" do
      @account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = @account
      it { expect(Task.create(:name => 'bar').valid?).to eq(true) }
  end

  describe "It should be possible to use aliased associations" do
    it { expect(AliasedTask.create(:name => 'foo', :project_alias => @project2).valid?).to eq(true) }
  end

  # Additional default_scopes
  describe 'When dealing with a user defined default_scope' do
    before do
      @account = Account.create!(:name => 'foo')
      @project1 = Project.create!(:name => 'inaccessible')
      @task1 = Task.create!(:name => 'no_tenant', :project => @project1)

      ActsAsTenant.current_tenant = @account
      @project2 = Project.create!(:name => 'accessible')
      @task2 = @project2.tasks.create!(:name => 'bar')
      @task3 = @project2.tasks.create!(:name => 'baz')
      @task4 = @project2.tasks.create!(:name => 'foo')
      @task5 = @project2.tasks.create!(:name => 'foobar', :completed => true )

      @tasks= Task.all
    end

    it 'should apply both the tenant scope and the user defined default_scope, including :order' do
      expect(@tasks.length).to eq(3)
      expect(@tasks).to eq([@task2, @task3, @task4])
    end
  end

  # Validates_uniqueness
  describe 'When using validates_uniqueness_to_tenant in a aat model' do
    before do
      account = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = account
      Project.create!(:name => 'existing_name')
    end

    it 'should not be possible to create a duplicate within the same tenant' do
      expect(Project.create(:name => 'existing_name').valid?).to eq(false)
    end

    it 'should be possible to create a duplicate outside the tenant scope' do
      account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = account
      expect(Project.create(:name => 'bar').valid?).to eq(true)
    end
  end

  describe 'Handles user defined scopes' do
    before do
      UniqueTask.create!(:name => 'foo', :user_defined_scope => 'unique_scope')
    end

    it { expect(UniqueTask.create(:name => 'foo', :user_defined_scope => 'another_scope')).to be_valid }
    it { expect(UniqueTask.create(:name => 'foo', :user_defined_scope => 'unique_scope')).not_to be_valid }
  end

  describe 'When using validates_uniqueness_of in a NON-aat model' do
    before do
      UnscopedModel.create!(:name => 'foo')
    end
    it 'should not be possible to create duplicates' do
      expect(UnscopedModel.create(:name => 'foo').valid?).to eq(false)
    end
  end

  # ::with_tenant
  describe "::with_tenant" do
    it "should set current_tenant to the specified tenant inside the block" do
      @account = Account.create!(:name => 'baz')

      ActsAsTenant.with_tenant(@account) do
        expect(ActsAsTenant.current_tenant).to eq(@account)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      ActsAsTenant.current_tenant = @account1
      ActsAsTenant.with_tenant @account2 do

      end

      expect(ActsAsTenant.current_tenant).to eq(@account1)
    end

    it "should return the value of the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      ActsAsTenant.current_tenant = @account1
      value = ActsAsTenant.with_tenant @account2 do
        "something"
      end

      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.with_tenant(nil) }.to raise_error(ArgumentError, /block required/)
    end
  end

  # Tenant required
  context "tenant required" do
    describe "raises exception if no tenant specified" do
      before do
        @account1 = Account.create!(:name => 'foo')
        @project1 = @account1.projects.create!(:name => 'foobar')
        allow(ActsAsTenant.configuration).to receive_messages(require_tenant: true)
      end

      it "should raise an error when no tenant is provided" do
        expect { Project.all.load }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end
    end
  end

  context "no tenant required" do
    describe "does not raise exception if no tenant specified" do
      before do
        @account1 = Account.create!(:name => 'foo')
        @project1 = @account1.projects.create!(:name => 'foobar')
      end

      it "should not raise an error when no tenant is provided" do
        expect { Project.all }.to_not raise_error
      end
    end
  end

  context 'include nulls' do
    describe 'when true' do
      before do
        @account1 = Account.create!(:name => 'foo')
        @account2 = Account.create!(:name => 'wat')
        @taskA = SharedTask.create!(name: 'Common')
        @task1 = ActsAsTenant.with_tenant(@account1){SharedTask.create!(name: 'Tenanted1')}
        @task2 = ActsAsTenant.with_tenant(@account2){SharedTask.create!(name: 'Tenanted2')}
      end

      it 'should return objects for nil tenant' do
        expect(SharedTask.count).to eq(3)
        expect(SharedTask.all).to eq [@taskA, @task1, @task2]
      end

      it 'should return objects for tenant1' do
        ActsAsTenant.current_tenant = @account1
        expect(SharedTask.count).to eq(2)
        expect(SharedTask.all).to eq [@taskA, @task1]
      end

      it 'should return objects for tenant2' do
        ActsAsTenant.current_tenant = @account2
        expect(SharedTask.count).to eq(2)
        expect(SharedTask.all).to eq [@taskA, @task2]
      end
    end
  end
end
