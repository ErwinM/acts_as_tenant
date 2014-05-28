require 'spec_helper'

# Setup the db
ActiveRecord::Schema.define(:version => 1) do
  create_table :accounts, :force => true do |t|
    t.column :name, :string
    t.column :subdomain, :string
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

  create_table :businesses, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

  create_table :irregular_inflection_tasks, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :business_id, :integer
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

class Business < ActiveRecord::Base
  has_many :tasks, class_name: 'IrregularInflectionTask'
  acts_as_tenant :account
end

class IrregularInflectionTask < ActiveRecord::Base
  belongs_to :business
  acts_as_tenant :account
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
    it {Project.respond_to?(:scoped_by_tenant?).should == true}
  end

  describe 'is_scoped_as_tenant should return the correct value when false' do
    it {UnscopedModel.respond_to?(:scoped_by_tenant?).should == false}
  end

  describe 'tenant_id should be immutable, if already set' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = @account.projects.create!(:name => 'bar')
    end

    it { lambda {@project.account_id = @account.id + 1}.should raise_error }
  end

  describe 'tenant_id should be mutable, if not already set' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = Project.create!(:name => 'bar')
    end

    it { @project.account_id.should be_nil }
    it { lambda { @project.account = @account }.should_not raise_error }
  end

  describe 'tenant_id should auto populate after initialization' do
    before do
      @account = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = @account
    end
    it {Project.new.account_id.should == @account.id}
  end

  describe 'Handles custom foreign_key on tenant model' do
    before do
      @account  = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = @account
      @custom_foreign_key_task = CustomForeignKeyTask.create!(:name => 'foo')
    end

    it { @custom_foreign_key_task.account.should == @account }
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

    it { @projects.length.should == 1 }
    it { @projects.should == [@project1] }
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

    it { @projects.count.should == 2 }
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
      @task2.account.should == @account
    end

    it 'should filter out the non-tenant task from the project' do
      @tasks.length.should == 1
    end
  end

  describe 'Associations can only be made with in-scope objects' do
    describe 'Regular inflection associations' do
      before do
        @account = Account.create!(:name => 'foo')
        @project1 = Project.create!(:name => 'inaccessible_project', :account_id => @account.id + 1)

        ActsAsTenant.current_tenant = @account
        @project2 = Project.create!(:name => 'accessible_project')
        @task = @project2.tasks.create!(:name => 'bar')
      end

      it { @task.update_attributes(:project_id => @project1.id).should == false }
    end

    describe 'Irregular inflection associations' do
      before do
        @account = Account.create!(:name => 'foo')
        @business1 = Business.create!(:name => 'inaccessible_business', :account_id => @account.id + 1)

        ActsAsTenant.current_tenant = @account
        @business2 = Business.create!(:name => 'accessible_business')
        @task = @business2.tasks.create!(:name => 'bar')
      end

      it { @task.update_attributes(:business_id => @business1.id).should == false }
    end
  end

  describe "Create and save an AaT-enabled child without it having a parent" do
      @account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = @account
      Task.create(:name => 'bar').valid?.should == true
  end

  describe "It should be possible to use aliased associations" do
    it { AliasedTask.create(:name => 'foo', :project_alias => @project2).valid?.should == true }
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
      @tasks.length.should == 3
      @tasks.should == [@task2, @task3, @task4]
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
      Project.create(:name => 'existing_name').valid?.should == false
    end

    it 'should be possible to create a duplicate outside the tenant scope' do
      account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = account
      Project.create(:name => 'bar').valid?.should == true
    end
  end

  describe 'Handles user defined scopes' do
    before do
      UniqueTask.create!(:name => 'foo', :user_defined_scope => 'unique_scope')
    end

    it { UniqueTask.create(:name => 'foo', :user_defined_scope => 'another_scope').should be_valid }
    it { UniqueTask.create(:name => 'foo', :user_defined_scope => 'unique_scope').should_not be_valid }
  end

  describe 'When using validates_uniqueness_of in a NON-aat model' do
    before do
      UnscopedModel.create!(:name => 'foo')
    end
    it 'should not be possible to create duplicates' do
      UnscopedModel.create(:name => 'foo').valid?.should == false
    end
  end

  # ::with_tenant
  describe "::with_tenant" do
    it "should set current_tenant to the specified tenant inside the block" do
      @account = Account.create!(:name => 'baz')

      ActsAsTenant.with_tenant(@account) do
        ActsAsTenant.current_tenant.should eq(@account)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      ActsAsTenant.current_tenant = @account1
      ActsAsTenant.with_tenant @account2 do

      end

      ActsAsTenant.current_tenant.should eq(@account1)
    end

    it "should return the value of the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      ActsAsTenant.current_tenant = @account1
      value = ActsAsTenant.with_tenant @account2 do
        "something"
      end

      value.should eq "something"
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
        ActsAsTenant.configuration.stub(require_tenant: true)
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
end
