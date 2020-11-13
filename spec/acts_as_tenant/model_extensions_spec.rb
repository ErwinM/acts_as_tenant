require "spec_helper"

describe ActsAsTenant do
  after { ActsAsTenant.current_tenant = nil }

  # Setting and getting
  describe "Setting the current tenant" do
    before { ActsAsTenant.current_tenant = :foo }
    it { expect(ActsAsTenant.current_tenant).to eq(:foo) }
  end

  describe "is_scoped_as_tenant should return the correct value when true" do
    it { expect(Project.respond_to?(:scoped_by_tenant?)).to eq(true) }
  end

  describe "is_scoped_as_tenant should return the correct value when false" do
    it { expect(UnscopedModel.respond_to?(:scoped_by_tenant?)).to eq(false) }
  end

  describe "tenant_id should be immutable, if already set" do
    before do
      @account = Account.create!(name: "foo")
      @project = @account.projects.create!(name: "bar")
    end

    it { expect { @project.account_id = @account.id + 1 }.to raise_error(ActsAsTenant::Errors::TenantIsImmutable) }
  end

  describe "setting tenant_id to the same value should not error" do
    before do
      @account = Account.create!(name: "foo")
      @project = @account.projects.create!(name: "bar")
    end

    it { expect { @project.account_id = @account.id }.not_to raise_error }
  end

  describe "setting tenant_id to a string with same to_i value should not error" do
    before do
      @account = Account.create!(name: "foo")
      @project = @account.projects.create!(name: "bar")
    end

    it { expect { @project.account_id = @account.id.to_s }.not_to raise_error }
  end

  describe "tenant_id should be mutable, if not already set" do
    before do
      @account = Account.create!(name: "foo")
      @project = Project.create!(name: "bar")
    end

    it { expect(@project.account_id).to be_nil }
    it { expect { @project.account = @account }.not_to raise_error }
  end

  describe "tenant_id should auto populate after initialization" do
    before do
      @account = Account.create!(name: "foo")
      ActsAsTenant.current_tenant = @account
    end
    it { expect(Project.new.account_id).to eq(@account.id) }
  end

  describe "Handles custom foreign_key on tenant model" do
    before do
      @account = Account.create!(name: "foo")
      ActsAsTenant.current_tenant = @account
      @custom_foreign_key_task = CustomForeignKeyTask.create!(name: "foo")
    end

    it { expect(@custom_foreign_key_task.account).to eq(@account) }
  end

  describe "Handles custom primary_key on tenant model" do
    before do
      @account = Account.create!(name: "foo")
      CustomPrimaryKeyTask.create!(name: "bar")
      ActsAsTenant.current_tenant = @account
      @custom_primary_key_task = CustomPrimaryKeyTask.create!
    end

    it { expect(@custom_primary_key_task.account).to eq(@account) }
    it { expect(CustomPrimaryKeyTask.count).to eq(1) }
  end

  describe "Handles counter_cache on tenant model" do
    before do
      @account = Account.create!(name: "foo")
      ActsAsTenant.current_tenant = @account
      @project = CustomCounterCacheTask.create!(name: "bar")
    end

    it "should correctly increment and decrement the tenants column" do
      expect(@account.reload.projects_count).to eq(1)
      @project.destroy
      expect(@account.reload.projects_count).to eq(0)
    end
  end

  describe "Handles tenant model updates" do
    before do
      @account = Account.create!(name: "foo")
      @project = @account.projects.create!(name: "bar")
    end

    it "should fetch tenant object through belongs_to to avoid accessing stale tenant object if that was updated" do
      # Sets current tenant in a way that it does not share the same memory reference of `@account`.
      ActsAsTenant.current_tenant = Account.find_by(name: "foo")

      expect(@project.account.name).to eq("foo")
      @account.update!(name: "Acme")
      expect(@project.account.name).to eq("Acme")
    end
  end

  # Scoping models
  describe "Project.all should be scoped to the current tenant if set" do
    before do
      @account1 = Account.create!(name: "foo")
      @account2 = Account.create!(name: "bar")

      @project1 = @account1.projects.create!(name: "foobar")
      @project2 = @account2.projects.create!(name: "baz")

      ActsAsTenant.current_tenant = @account1
      @projects = Project.all
    end

    it { expect(@projects.length).to eq(1) }
    it { expect(@projects).to eq([@project1]) }
  end

  describe "Project.unscoped.all should return the unscoped value" do
    before do
      @account1 = Account.create!(name: "foo")
      @account2 = Account.create!(name: "bar")

      @project1 = @account1.projects.create!(name: "foobar")
      @project2 = @account2.projects.create!(name: "baz")

      ActsAsTenant.current_tenant = @account1
      @projects = Project.unscoped
    end

    it { expect(@projects.count).to eq(2) }
  end

  describe "Querying the tenant from a scoped model without a tenant set" do
    before do
      @project = Project.create!(name: "bar")
    end

    it { @project.account }
  end

  describe "Querying the tenant from a scoped model with a tenant set" do
    before do
      @account = Account.create!(name: "foo")
      @project = @account.projects.create!(name: "foobar")
      ActsAsTenant.current_tenant = @account1
    end

    it { @project.account }
  end

  describe "A tenant model with global records" do
    before do
      @account = Account.create!(name: "foo")
      @project1 = GlobalProject.create!(name: "foobar global")
      @project2 = GlobalProject.create!(name: "unaccessible project", account: Account.create!)
      ActsAsTenant.current_tenant = @account
      @project3 = GlobalProject.create!(name: "foobar")
    end

    it "should return two projects" do
      expect(GlobalProject.all.count).to eq(2)
    end

    it "should validate the project name against the global records too" do
      expect(GlobalProject.new(name: "foobar").valid?).to be(false)
      expect(GlobalProject.new(name: "foobar new").valid?).to be(true)
      expect(GlobalProject.new(name: "foobar global").valid?).to be(false)
      expect(@project1.valid?).to be(true)
    end

    it "should add the model to ActsAsTenant.models_with_global_records" do
      expect(ActsAsTenant.models_with_global_records.include?(GlobalProject)).to be(true)
      expect(ActsAsTenant.models_with_global_records.include?(Project)).to be(false)
    end
  end

  # Associations
  describe "Associations should be correctly scoped by current tenant" do
    before do
      @account = Account.create!(name: "foo")
      @project = Project.create!(name: "foobar", account: @account)
      # the next line should normally be (nearly) impossible: a task assigned to a tenant project,
      # but the task has no tenant assigned
      @task1 = Task.create!(name: "no_tenant", project: @project)

      ActsAsTenant.current_tenant = @account
      @task2 = @project.tasks.create!(name: "baz")

      @project.reload
    end

    it "should correctly set the tenant on the task created with current_tenant set" do
      expect(@task2.account).to eq(@account)
    end

    it "should filter out the non-tenant task from the project" do
      expect(@project.tasks.length).to eq(1)
    end
  end

  describe "Associations can only be made with in-scope objects" do
    before do
      @account = Account.create!(name: "foo")
      @project1 = Project.create!(name: "inaccessible_project", account: Account.create!)
      ActsAsTenant.current_tenant = @account

      @project2 = Project.create!(name: "accessible_project")
      @task = @project2.tasks.create!(name: "bar")
    end

    it { expect(@task.update(project_id: @project1.id)).to eq(false) }
  end

  describe "Create and save an AaT-enabled child without it having a parent" do
    before do
      @account = Account.create!(name: "baz")
      ActsAsTenant.current_tenant = @account
    end
    it { expect(Task.create(name: "bar").valid?).to eq(true) }
  end

  describe "It should be possible to use aliased associations" do
    it { expect(AliasedTask.create(name: "foo", project_alias: @project2).valid?).to eq(true) }
  end

  describe "It should be possible to use associations with foreign_key from polymorphic" do
    context "tenanted objects have a polymorphic association" do
      before do
        @account = Account.create!(name: "foo")
        ActsAsTenant.current_tenant = @account
        @project = Project.create!(name: "project", account: @account)
        @comment = Comment.new commentable: @project, account: @account
      end

      it { expect(@comment.save!).to eq(true) }
    end

    context "tenant is polymorphic" do
      before do
        @account = Account.create!(name: "foo")
        @project = Project.create!(name: "polymorphic project")
        ActsAsTenant.current_tenant = @project
        @comment = PolymorphicTenantComment.new(account: @account)
      end

      it "populates commentable_type with the current tenant" do
        expect(@comment.polymorphic_tenant_commentable_id).to eql(@project.id)
        expect(@comment.polymorphic_tenant_commentable_type).to eql(@project.class.to_s)
      end

      context "with another type of tenant, same id" do
        before do
          @comment.save!
          @article = Article.create!(id: @project.id, title: "article title")
          @comment_on_article = @article.polymorphic_tenant_comments.create!
        end

        it "correctly scopes to the current tenant type" do
          expect(@comment_on_article).to be_persisted
          expect(@comment).to be_persisted
          expect(PolymorphicTenantComment.count).to eql(1)
          expect(PolymorphicTenantComment.all.first.attributes).to eql(@comment.attributes)
        end
      end
    end
  end

  # Additional default_scopes
  describe "When dealing with a user defined default_scope" do
    before do
      @account = Account.create!(name: "foo")
      @project1 = Project.create!(name: "inaccessible")
      @task1 = Task.create!(name: "no_tenant", project: @project1)

      ActsAsTenant.current_tenant = @account
      @project2 = Project.create!(name: "accessible")
      @task2 = @project2.tasks.create!(name: "bar")
      @task3 = @project2.tasks.create!(name: "baz")
      @task4 = @project2.tasks.create!(name: "foo")
      @task5 = @project2.tasks.create!(name: "foobar", completed: true)

      @tasks = Task.all
    end

    it "should apply both the tenant scope and the user defined default_scope, including :order" do
      expect(@tasks.length).to eq(3)
      expect(@tasks).to eq([@task2, @task3, @task4])
    end
  end

  # Validates_uniqueness
  describe "When using validates_uniqueness_to_tenant in a aat model" do
    before do
      account = Account.create!(name: "foo")
      ActsAsTenant.current_tenant = account
      Project.create!(name: "existing_name")
    end

    it "should not be possible to create a duplicate within the same tenant" do
      expect(Project.create(name: "existing_name").valid?).to eq(false)
    end

    it "should be possible to create a duplicate outside the tenant scope" do
      account = Account.create!(name: "baz")
      ActsAsTenant.current_tenant = account
      expect(Project.create(name: "bar").valid?).to eq(true)
    end
  end

  describe "Handles user defined scopes" do
    before do
      UniqueTask.create!(name: "foo", user_defined_scope: "unique_scope")
    end

    it { expect(UniqueTask.create(name: "foo", user_defined_scope: "another_scope")).to be_valid }
    it { expect(UniqueTask.create(name: "foo", user_defined_scope: "unique_scope")).not_to be_valid }
  end

  describe "When using validates_uniqueness_of in a NON-aat model" do
    before do
      UnscopedModel.create!(name: "foo")
    end
    it "should not be possible to create duplicates" do
      expect(UnscopedModel.create(name: "foo").valid?).to eq(false)
    end
  end

  # ::with_tenant
  describe "::with_tenant" do
    it "should set current_tenant to the specified tenant inside the block" do
      @account = Account.create!(name: "baz")

      ActsAsTenant.with_tenant(@account) do
        expect(ActsAsTenant.current_tenant).to eq(@account)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(name: "foo")
      @account2 = Account.create!(name: "bar")

      ActsAsTenant.current_tenant = @account1
      ActsAsTenant.with_tenant @account2 do
      end

      expect(ActsAsTenant.current_tenant).to eq(@account1)
    end

    it "should return the value of the block" do
      @account1 = Account.create!(name: "foo")
      @account2 = Account.create!(name: "bar")

      ActsAsTenant.current_tenant = @account1
      value = ActsAsTenant.with_tenant(@account2) { "something" }

      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.with_tenant(nil) }.to raise_error(ArgumentError, /block required/)
    end
  end

  describe "::without_tenant" do
    it "should set current_tenant to nil inside the block" do
      ActsAsTenant.without_tenant do
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end

    it "should set current_tenant to nil even if default_tenant is set" do
      old_default_tenant = ActsAsTenant.default_tenant
      ActsAsTenant.default_tenant = Account.create!(name: "foo")
      ActsAsTenant.without_tenant do
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    ensure
      ActsAsTenant.default_tenant = old_default_tenant
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(name: "foo")

      ActsAsTenant.current_tenant = @account1
      ActsAsTenant.without_tenant do
      end

      expect(ActsAsTenant.current_tenant).to eq(@account1)
    end

    it "should return the value of the block" do
      value = ActsAsTenant.without_tenant {
        "something"
      }

      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.without_tenant }.to raise_error(ArgumentError, /block required/)
    end
  end

  # Tenant required
  context "tenant required" do
    before do
      @account1 = Account.create!(name: "foo")
      @project1 = @account1.projects.create!(name: "foobar")
      allow(ActsAsTenant.configuration).to receive_messages(require_tenant: true)
    end

    describe "raises exception if no tenant specified" do
      it "should raise an error when no tenant is provided" do
        expect { Project.all }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end
    end

    describe "does not raise exception when run in unscoped mode" do
      it "should not raise an error when no tenant is provided" do
        expect {
          ActsAsTenant.without_tenant { Project.all }
        }.to_not raise_error
      end
    end
  end

  context "no tenant required" do
    describe "does not raise exception if no tenant specified" do
      before do
        @account1 = Account.create!(name: "foo")
        @project1 = @account1.projects.create!(name: "foobar")
      end

      it "should not raise an error when no tenant is provided" do
        expect { Project.all }.to_not raise_error
      end
    end
  end

  describe "ActsAsTenant.default_tenant=" do
    before(:each) do
      @account = Account.create!
    end

    after(:each) do
      ActsAsTenant.default_tenant = nil
    end

    it "provides current_tenant" do
      ActsAsTenant.default_tenant = @account
      expect(ActsAsTenant.current_tenant).to eq(@account)
    end

    it "can be overridden by assignment" do
      ActsAsTenant.default_tenant = @account
      @account2 = Account.create!
      ActsAsTenant.current_tenant = @account2
      expect(ActsAsTenant.current_tenant).not_to eq(@account)
    end

    it "can be overridden by with_tenant" do
      ActsAsTenant.default_tenant = @account
      @account2 = Account.create!
      ActsAsTenant.with_tenant @account2 do
        expect(ActsAsTenant.current_tenant).to eq(@account2)
      end
      expect(ActsAsTenant.current_tenant).to eq(@account)
    end

    it "doesn't override existing current_tenant" do
      @account2 = Account.create!
      ActsAsTenant.current_tenant = @account2
      ActsAsTenant.default_tenant = @account
      expect(ActsAsTenant.current_tenant).to eq(@account2)
    end

    it "survives request resets" do
      ActsAsTenant.default_tenant = @account
      RequestStore.clear!
      expect(ActsAsTenant.current_tenant).to eq(@account)
    end
  end
end
