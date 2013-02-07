require 'spec_helper'

# Setup the db
ActiveRecord::Schema.define(:version => 2) do
  create_table :accounts, :force => true do |t|
    t.column :name, :string
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
  
  create_table :cities, :force => true do |t|
    t.column :name, :string
  end
  
  create_table :sub_tasks, :force => true do |t|
    t.column :name, :string
    t.column :something_else, :integer
  end

  create_table :tools, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

  create_table :managers_tools, {:force => true, id: false} do |t|
    t.integer :manager_id
    t.integer :tool_id
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
  has_and_belongs_to_many :tools

  acts_as_tenant :account
end

class Task < ActiveRecord::Base
  belongs_to :project
  default_scope :conditions => { :completed => nil }, :order => "name"
  
  acts_as_tenant :account
  validates_uniqueness_of :name
end

class City < ActiveRecord::Base
  validates_uniqueness_of :name
end

class SubTask < ActiveRecord::Base
  acts_as_tenant :account
  belongs_to :something_else, :class_name => "Project"
end

class Tool < ActiveRecord::Base
  has_and_belongs_to_many :managers

  acts_as_tenant :account
end

# Start testing!
describe ActsAsTenant do
  after { ActsAsTenant.current_tenant = nil }

  describe 'Setting the current tenant' do
    before { ActsAsTenant.current_tenant = :foo }
    it { ActsAsTenant.current_tenant == :foo }
  end
  
  describe 'is_scoped_as_tenant should return the correct value' do
    it {Project.respond_to?(:is_scoped_by_tenant?).should == true}
  end
  
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
      @projects = Project.unscoped.all
    end
    
    it { @projects.length.should == 2 }
  end
  
  describe 'Associations should be correctly scoped by current tenant' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = @account.projects.create!(:name => 'foobar', :account_id => @account.id )
      # the next line would normally be nearly impossible: a task assigned to a tenant project, 
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
  
  describe 'tenant_id should be immutable' do
    before do
      @account = Account.create!(:name => 'foo')
      @project = @account.projects.create!(:name => 'bar')
    end
    
    it { lambda {@project.account_id = @account.id + 1}.should raise_error }
  end
    
  describe 'Associations can only be made with in-scope objects' do
    before do
      @account = Account.create!(:name => 'foo')
      @project1 = Project.create!(:name => 'inaccessible_project', :account_id => @account.id + 1)
      
      ActsAsTenant.current_tenant = @account
      @project2 = Project.create!(:name => 'accessible_project')
      @task = @project2.tasks.create!(:name => 'bar')
    end
  
    it { @task.update_attributes(:project_id => @project1.id).should == false }
  end
  
  describe 'When using validates_uniqueness_to_tenant in a aat model' do
    before do
      @account = Account.create!(:name => 'foo')
      ActsAsTenant.current_tenant = @account
      @project1 = Project.create!(:name => 'bar')
    end
    
    it 'should not be possible to create a duplicate within the same tenant' do
      @project2 = Project.create(:name => 'bar').valid?.should == false
    end
    
    it 'should be possible to create a duplicate outside the tenant scope' do
      @account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = @account
      @project2 = Project.create(:name => 'bar').valid?.should == true
    end
  end
  
  describe 'When using validates_uniqueness_of in a NON-aat model' do
    before do
      @city1 = City.create!(:name => 'foo')
    end
    it 'should not be possible to create duplicates' do
      @city2 = City.create(:name => 'foo').valid?.should == false
    end
  end
  
  describe "It should be possible to use aliased associations" do
    it { @sub_task = SubTask.create(:name => 'foo').valid?.should == true }
  end
  
  describe "It should be possible to create and save an AaT-enabled child without it having a parent" do
      @account = Account.create!(:name => 'baz')
      ActsAsTenant.current_tenant = @account
      Task.create(:name => 'bar').valid?.should == true
  end

  describe "It should be possible to use direct many-to-many associations" do
      @manager = Manager.create!(:name => 'fool')
      @manager.tools.new(:name => 'golden hammer')
      @manager.save.should == true
  end

  describe "It should be possible to use direct many-to-many associations" do
    @manager = Manager.create!(:name => 'fool')
    @manager.tools.new(:name => 'golden hammer')
    @manager.save.should == true
  end

  describe "When using direct many-to-many associations they are correctly scoped to the tenant" do
    before do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      ActsAsTenant.current_tenant= @account1
      @manager1 = Manager.create!(:name => 'fool')
      @tool1 = @manager1.tools.create!(:name => 'golden hammer')

      ActsAsTenant.current_tenant= @account2
      @manager2 = Manager.create!(:name => 'pitty')
      @tool2 = @manager2.tools.create!(:name => 'golden saw')

      @tools = Tool.all
    end
    it { @tools.should == [@tool2] }
  end

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
end
