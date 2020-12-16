require "spec_helper"

describe ActsAsTenant do
  let(:account) { accounts(:foo) }

  it "can set the current tenant" do
    ActsAsTenant.current_tenant = :foo
    expect(ActsAsTenant.current_tenant).to eq(:foo)
  end

  it "is_scoped_as_tenant should return the correct value when true" do
    expect(Project.respond_to?(:scoped_by_tenant?)).to eq(true)
  end

  it "is_scoped_as_tenant should return the correct value when false" do
    expect(UnscopedModel.respond_to?(:scoped_by_tenant?)).to eq(false)
  end

  it "tenant_id should be immutable, if already set" do
    project = account.projects.create!(name: "bar")
    expect { project.account_id = account.id + 1 }.to raise_error(ActsAsTenant::Errors::TenantIsImmutable)
  end

  it "setting tenant_id to the same value should not error" do
    project = account.projects.create!(name: "bar")
    expect { project.account_id = account.id }.not_to raise_error
  end

  it "setting tenant_id to a string with same to_i value should not error" do
    project = account.projects.create!(name: "bar")
    expect { project.account_id = account.id.to_s }.not_to raise_error
  end

  it "tenant_id should be mutable, if not already set" do
    project = projects(:without_account)
    expect(project.account_id).to be_nil
    expect { project.account = account }.not_to raise_error
  end

  it "tenant_id should auto populate after initialization" do
    ActsAsTenant.current_tenant = account
    expect(Project.new.account_id).to eq(account.id)
  end

  it "handles custom foreign_key on tenant model" do
    ActsAsTenant.current_tenant = account
    custom_foreign_key_task = CustomForeignKeyTask.create!(name: "foo")
    expect(custom_foreign_key_task.account).to eq(account)
  end

  it "handles custom primary_key on tenant model" do
    ActsAsTenant.current_tenant = account
    custom_primary_key_task = CustomPrimaryKeyTask.create!
    expect(custom_primary_key_task.account).to eq(account)
    expect(CustomPrimaryKeyTask.count).to eq(1)
  end

  it "should correctly increment and decrement the tenants counter_cache column" do
    ActsAsTenant.current_tenant = account
    project = CustomCounterCacheTask.create!(name: "bar")
    expect(account.reload.projects_count).to eq(1)
    project.destroy
    expect(account.reload.projects_count).to eq(0)
  end

  it "does not cache account association" do
    project = account.projects.first
    ActsAsTenant.current_tenant = account
    expect(project.account.name).to eq(account.name)
    account.update!(name: "Acme")
    expect(project.account.name).to eq("Acme")
  end

  it "Querying the tenant from a scoped model without a tenant set" do
    expect(projects(:foo).account).to_not be_nil
  end

  it "Querying the tenant from a scoped model with a tenant set" do
    ActsAsTenant.current_tenant = account
    expect(projects(:foo).account).to eq(accounts(:foo))
    expect(projects(:bar).account).to eq(accounts(:bar))
  end

  describe "scoping models" do
    it "should scope Project.all to the current tenant if set" do
      ActsAsTenant.current_tenant = account
      expect(Project.count).to eq(account.projects.count)
      expect(Project.all).to eq(account.projects)
    end

    it "should allow unscoping" do
      ActsAsTenant.current_tenant = account
      expect(Project.unscoped.count).to be > account.projects.count
    end

    it "returns nothing with unsaved tenant" do
      ActsAsTenant.current_tenant = Account.new
      expect(Project.all.count).to eq(0)
    end
  end

  describe "A tenant model with global records" do
    before do
      ActsAsTenant.current_tenant = account
    end

    it "should return global and tenant projects" do
      expect(GlobalProject.count).to eq(GlobalProject.unscoped.where(account: [nil, account]).count)
    end

    it "returns global records with unsaved tenant" do
      ActsAsTenant.current_tenant = Account.new
      expect(GlobalProject.all.count).to eq(GlobalProject.unscoped.where(account: [nil]).count)
    end

    it "should add the model to ActsAsTenant.models_with_global_records" do
      expect(ActsAsTenant.models_with_global_records.include?(GlobalProject)).to be_truthy
      expect(ActsAsTenant.models_with_global_records.include?(Project)).to be_falsy
    end

    context "should validate tenant records against global & tenant records" do
      it "global records are valid" do
        expect(global_projects(:global).valid?).to be(true)
      end

      it "allows separate global and tenant records" do
        expect(GlobalProject.new(name: "foo new").valid?).to be(true)
      end

      it "is valid if tenant is different" do
        ActsAsTenant.current_tenant = accounts(:bar)

        expect(GlobalProject.new(name: "global foo").valid?).to be(true)
      end

      it "is invalid with duplicate tenant records" do
        expect(GlobalProject.new(name: "global foo").valid?).to be(false)
      end

      it "is invalid if tenant record conflicts with global record" do
        expect(GlobalProject.new(name: "global").valid?).to be(false)
      end
    end

    context "should validate global records against global & tenant records" do
      before do
        ActsAsTenant.current_tenant = nil
      end

      it "is invalid if global record conflicts with tenant record" do
        expect(GlobalProject.new(name: "global foo").valid?).to be(false)
      end
    end

    context "with conditions in args" do
      it "respects conditions" do
        expect(GlobalProjectWithConditions.new(name: "foo").valid?).to be(false)
        expect(GlobalProjectWithConditions.new(name: "global foo").valid?).to be(true)
      end
    end

    context "with if in args" do
      it "respects if" do
        expect(GlobalProjectWithIf.new(name: "foo").valid?).to be(false)
        expect(GlobalProjectWithIf.new(name: "global foo").valid?).to be(true)
      end
    end
  end

  # Associations
  context "Associations should be correctly scoped by current tenant" do
    before do
      @project = account.projects.create!(name: "foobar")

      # the next line should normally be (nearly) impossible: a task assigned to a tenant project,
      # but the task has no tenant assigned
      @task1 = Task.create!(name: "no_tenant", project: @project)

      ActsAsTenant.current_tenant = account
      @task2 = @project.tasks.create!(name: "baz")

      @project.reload
    end

    it "should correctly set the tenant on the task created with current_tenant set" do
      expect(@task2.account).to eq(account)
    end

    it "should filter out the non-tenant task from the project" do
      expect(@project.tasks.length).to eq(1)
    end
  end

  it "associations can only be made with in-scope objects" do
    project1 = accounts(:bar).projects.create!(name: "inaccessible_project")
    ActsAsTenant.current_tenant = account

    project2 = Project.create!(name: "accessible_project")
    task = project2.tasks.create!(name: "bar")

    expect(task.update(project_id: project1.id)).to eq(false)
  end

  it "can create and save an AaT-enabled child without it having a parent" do
    ActsAsTenant.current_tenant = account
    expect(Task.new(name: "bar").valid?).to eq(true)
  end

  it "should be possible to use aliased associations" do
    expect(AliasedTask.create(name: "foo", project_alias: @project2).valid?).to eq(true)
  end

  describe "It should be possible to use associations with foreign_key from polymorphic" do
    it "tenanted objects have a polymorphic association" do
      ActsAsTenant.current_tenant = account
      expect { Comment.create!(commentable: account.projects.first) }.not_to raise_error
    end

    context "tenant is polymorphic" do
      before do
        @project = Project.create!(name: "polymorphic project")
        ActsAsTenant.current_tenant = @project
        @comment = PolymorphicTenantComment.new(account: account)
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
  it "should apply both the tenant scope and the user defined default_scope, including :order" do
    project1 = Project.create!(name: "inaccessible")
    Task.create!(name: "no_tenant", project: project1)

    ActsAsTenant.current_tenant = account
    project2 = Project.create!(name: "accessible")
    task2 = project2.tasks.create!(name: "bar")
    task3 = project2.tasks.create!(name: "baz")
    task4 = project2.tasks.create!(name: "foo")
    project2.tasks.create!(name: "foobar", completed: true)

    tasks = Task.all

    expect(tasks.length).to eq(3)
    expect(tasks).to eq([task2, task3, task4])
  end

  # Validates_uniqueness
  context "When using validates_uniqueness_to_tenant in a aat model" do
    before do
      @name = "existing_name"
      ActsAsTenant.current_tenant = account
      Project.create!(name: @name)
    end

    it "should not be possible to create a duplicate within the same tenant" do
      expect(Project.new(name: @name).valid?).to eq(false)
    end

    it "should be possible to create a duplicate in another tenant" do
      ActsAsTenant.current_tenant = accounts(:bar)
      expect(Project.create(name: @name).valid?).to eq(true)
    end
  end

  it "handles user defined scopes" do
    UniqueTask.create!(name: "foo", user_defined_scope: "unique_scope")
    expect(UniqueTask.create(name: "foo", user_defined_scope: "another_scope")).to be_valid
    expect(UniqueTask.create(name: "foo", user_defined_scope: "unique_scope")).not_to be_valid
  end

  context "When using validates_uniqueness_of in a NON-aat model" do
    it "should not be possible to create duplicates" do
      UnscopedModel.create!(name: "foo")
      expect(UnscopedModel.create(name: "foo").valid?).to eq(false)
    end
  end

  # ::with_tenant
  describe "::with_tenant" do
    it "should set current_tenant to the specified tenant inside the block" do
      ActsAsTenant.with_tenant(account) do
        expect(ActsAsTenant.current_tenant).to eq(account)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      ActsAsTenant.current_tenant = account
      ActsAsTenant.with_tenant(accounts(:bar)) {}
      expect(ActsAsTenant.current_tenant).to eq(account)
    end

    it "should return the value of the block" do
      ActsAsTenant.current_tenant = account
      value = ActsAsTenant.with_tenant(accounts(:bar)) { "something" }
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
      ActsAsTenant.current_tenant = account
      ActsAsTenant.without_tenant {}
      expect(ActsAsTenant.current_tenant).to eq(account)
    end

    it "should return the value of the block" do
      value = ActsAsTenant.without_tenant { "something" }
      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.without_tenant }.to raise_error(ArgumentError, /block required/)
    end
  end

  # Tenant required
  context "tenant required" do
    before do
      account.projects.create!(name: "foobar")
      allow(ActsAsTenant.configuration).to receive_messages(require_tenant: true)
    end

    it "should raise an error when no tenant is provided" do
      expect { Project.all }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it "should not raise an error when no tenant is provided" do
      expect { ActsAsTenant.without_tenant { Project.all } }.to_not raise_error
    end
  end

  context "no tenant required" do
    it "should not raise an error when no tenant is provided" do
      expect { Project.all }.to_not raise_error
    end
  end

  describe "ActsAsTenant.default_tenant=" do
    after(:each) do
      ActsAsTenant.default_tenant = nil
    end

    it "provides current_tenant" do
      ActsAsTenant.default_tenant = account
      expect(ActsAsTenant.current_tenant).to eq(account)
    end

    it "can be overridden by assignment" do
      ActsAsTenant.default_tenant = account
      ActsAsTenant.current_tenant = accounts(:bar)
      expect(ActsAsTenant.current_tenant).to eq(accounts(:bar))
    end

    it "can be overridden by with_tenant" do
      ActsAsTenant.default_tenant = account
      ActsAsTenant.with_tenant accounts(:bar) do
        expect(ActsAsTenant.current_tenant).to eq(accounts(:bar))
      end
      expect(ActsAsTenant.current_tenant).to eq(account)
    end

    it "doesn't override existing current_tenant" do
      ActsAsTenant.current_tenant = accounts(:bar)
      ActsAsTenant.default_tenant = account
      expect(ActsAsTenant.current_tenant).to eq(accounts(:bar))
    end

    it "survives request resets" do
      ActsAsTenant.default_tenant = account
      RequestStore.clear!
      expect(ActsAsTenant.current_tenant).to eq(account)
    end
  end
end
