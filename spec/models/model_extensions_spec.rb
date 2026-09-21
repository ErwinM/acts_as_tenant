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

  it "setting tenant_id to nil should throw error" do
    project = account.projects.create!(name: "bar")
    expect { project.account_id = nil }.to raise_error(ActsAsTenant::Errors::TenantIsImmutable)
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

  describe "acts_as_tenant :through" do
    let(:account) { accounts(:abc) }

    it "should scope User.all to the current tenant if set" do
      ActsAsTenant.current_tenant = account
      expect(User.count).to eq(account.users.count)
      expect(User.all).to eq(account.users)
    end

    it "should return all users when no current tenant is set" do
      expect(User.count).to eq(3)
    end

    it "should allow unscoping" do
      ActsAsTenant.current_tenant = account
      expect(User.unscoped.count).to be > account.users.count
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

      it "is invalid if tenant record conflicts with global record with scope" do
        duplicate = GlobalProjectWithScope.new(
          name: "global scope",
          user_defined_scope: "abc"
        )
        expect(duplicate.valid?).to be(false)
      end

      it "is invalid if any of multiple fields conflicts with a global record" do
        expect(GlobalProjectWithMultipleFields.new(name: "global", user_defined_scope: "new").valid?).to be(false)
        expect(GlobalProjectWithMultipleFields.new(name: "new", user_defined_scope: "abc").valid?).to be(false)
        expect(GlobalProjectWithMultipleFields.new(name: "new", user_defined_scope: "new").valid?).to be(true)
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

  it "validates associations declared after acts_as_tenant" do
    project1 = accounts(:bar).projects.create!(name: "inaccessible_project")
    ActsAsTenant.current_tenant = account

    task = LateAssociationTask.new(name: "bar", project_id: project1.id)

    expect(task.valid?).to eq(false)
    expect(task.errors[:project_id]).to include("association is invalid [ActsAsTenant]")
  end

  it "validates associations declared on an STI subclass" do
    project1 = accounts(:bar).projects.create!(name: "inaccessible_project")
    ActsAsTenant.current_tenant = account

    task = StiProjectTask.new(name: "bar", project_id: project1.id)

    expect(task.valid?).to eq(false)
    expect(task.errors[:project_id]).to include("association is invalid [ActsAsTenant]")
  end

  describe "validating associations without a current tenant" do
    it "is invalid when the associated record belongs to another tenant" do
      project = accounts(:bar).projects.create!(name: "other_tenant_project")
      task = Task.new(name: "bar", account: account, project: project)

      expect(task.valid?).to eq(false)
      expect(task.errors[:project_id]).to include("association is invalid [ActsAsTenant]")
    end

    it "is invalid when only the foreign key is assigned" do
      project = accounts(:bar).projects.create!(name: "other_tenant_project")
      task = Task.new(name: "bar", account: account, project_id: project.id)

      expect(task.valid?).to eq(false)
      expect(task.errors[:project_id]).to include("association is invalid [ActsAsTenant]")
    end

    it "is invalid inside without_tenant" do
      project = accounts(:bar).projects.create!(name: "other_tenant_project")
      task = Task.new(name: "bar", account: account, project: project)

      expect(ActsAsTenant.without_tenant { task.valid? }).to eq(false)
    end

    it "is valid when the associated record belongs to the same tenant" do
      project = account.projects.create!(name: "same_tenant_project")

      expect(Task.new(name: "bar", account: account, project: project).valid?).to eq(true)
    end

    it "is valid when the associated record has no tenant" do
      project = Project.create!(name: "global_project")

      expect(Task.new(name: "bar", account: account, project: project).valid?).to eq(true)
    end

    it "is valid when the record has no tenant" do
      project = account.projects.create!(name: "same_tenant_project")

      expect(Task.new(name: "bar", project: project).valid?).to eq(true)
    end

    context "with polymorphic tenants" do
      let(:project) { Project.create!(name: "polymorphic project") }
      let(:article) { Article.create!(id: project.id, title: "same id article") }

      it "is invalid when the tenants have the same id but a different type" do
        comment = PolymorphicTenantComment.create!(polymorphic_tenant_commentable: article)
        reply = PolymorphicTenantReply.new(polymorphic_tenant_commentable: project, polymorphic_tenant_comment: comment)

        expect(reply.valid?).to eq(false)
        expect(reply.errors[:polymorphic_tenant_comment_id]).to include("association is invalid [ActsAsTenant]")
      end

      it "is valid when the tenants have the same id and type" do
        comment = PolymorphicTenantComment.create!(polymorphic_tenant_commentable: project)
        reply = PolymorphicTenantReply.new(polymorphic_tenant_commentable: project, polymorphic_tenant_comment: comment)

        expect(reply.valid?).to eq(true)
      end
    end

    it "skips associated models scoped through another association" do
      user = User.create!(email: "user@example.com")

      expect(UsersAccount.new(user: user, account: account).valid?).to eq(true)
    end
  end

  it "looks up associations by the associated model's primary key" do
    project = account.projects.create!(name: "keyed_project")
    ActsAsTenant.current_tenant = account

    expect(KeyedTask.new(project: project).valid?).to eq(true)
  end

  it "can create and save an AaT-enabled child without it having a parent" do
    ActsAsTenant.current_tenant = account
    expect(Task.new(name: "bar").valid?).to eq(true)
  end

  it "should be possible to use aliased associations" do
    expect(AliasedTask.create(name: "foo", project_alias: @project2).valid?).to eq(true)
  end

  it "uses the scope passed to acts_as_tenant" do
    account.update!(deleted_at: Time.now)
    manager = Manager.create!(account_id: account.id)

    expect(manager.valid?).to eq(true)
    expect(manager.account).to eq(account)
  end

  it "uses the scope passed to belongs_to when validating" do
    project = account.projects.create!(name: "foobar", deleted_at: Time.now)
    manager = Manager.new(account: account, project: project)

    expect(manager.valid?).to eq(true)
  end

  describe "assigning the tenant when creating records" do
    before { ActsAsTenant.current_tenant = account }

    it "sets the current tenant when none is assigned" do
      expect(Project.create!(name: "new").account).to eq(account)
    end

    it "is invalid when assigned another tenant" do
      [
        Project.new(name: "by id", account_id: accounts(:bar).id),
        Project.new(name: "by association", account: accounts(:bar)),
        accounts(:bar).projects.build(name: "through the tenant")
      ].each do |project|
        expect(project).not_to be_valid
        expect(project.errors[:account_id]).to include("must be the current tenant [ActsAsTenant]")
      end
    end

    it "is valid when assigned the current tenant" do
      expect(Project.new(name: "mine", account: account)).to be_valid
    end

    it "is invalid when a record without a tenant is assigned another tenant" do
      project = projects(:without_account)
      project.account = accounts(:bar)

      expect(project).not_to be_valid
    end

    it "allows creating records for another tenant in with_tenant" do
      project = ActsAsTenant.with_tenant(accounts(:bar)) { Project.create!(name: "theirs") }

      expect(project.account).to eq(accounts(:bar))
    end

    it "allows creating records for any tenant without a tenant" do
      ActsAsTenant.current_tenant = nil

      expect(Project.create!(name: "any", account: accounts(:bar)).account).to eq(accounts(:bar))
    end

    it "is invalid when a polymorphic tenant is another record" do
      ActsAsTenant.current_tenant = projects(:foo)

      expect(PolymorphicTenantComment.new(polymorphic_tenant_commentable: account)).not_to be_valid
      expect(PolymorphicTenantComment.new(polymorphic_tenant_commentable: projects(:bar))).not_to be_valid
      expect(PolymorphicTenantComment.new(polymorphic_tenant_commentable: projects(:foo))).to be_valid
    end
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

      it "doesn't return another tenant type's records with the same id" do
        project_comment = PolymorphicTenantComment.create!
        article = Article.create!(id: @project.id, title: "article title")
        ActsAsTenant.with_tenant(article) { article.polymorphic_tenant_comments.create! }

        expect(PolymorphicTenantComment.all).to eq([project_comment])
      end

      context "with an STI tenant" do
        let(:article) { FeaturedArticle.create!(title: "featured") }

        it "stores the tenant's polymorphic_name" do
          ActsAsTenant.current_tenant = article
          comment = PolymorphicTenantComment.create!

          expect(comment.polymorphic_tenant_commentable_type).to eq("Article")
          expect(article.polymorphic_tenant_comments).to eq([comment])
        end

        it "scopes to records saved with the tenant's class name" do
          comment = ActsAsTenant.without_tenant do
            PolymorphicTenantComment.create!(polymorphic_tenant_commentable_id: article.id, polymorphic_tenant_commentable_type: "FeaturedArticle")
          end
          ActsAsTenant.current_tenant = article

          expect(PolymorphicTenantComment.all).to eq([comment])
        end
      end

      it "sets the tenant on records built before the tenant was set" do
        ActsAsTenant.current_tenant = nil
        comment = PolymorphicTenantComment.new(account: account)
        ActsAsTenant.current_tenant = @project
        comment.save!

        expect(comment.polymorphic_tenant_commentable_id).to eql(@project.id)
        expect(comment.polymorphic_tenant_commentable_type).to eql("Project")
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

  it "validates uniqueness with the model's tenant when another model's tenant was declared last" do
    previous_tenant_klass = ActsAsTenant.tenant_klass
    ActsAsTenant.set_tenant_klass(:polymorphic_tenant_commentable)
    stub_const("SubclassedProject", Class.new(Project) { validates_uniqueness_to_tenant :user_defined_scope })

    ActsAsTenant.current_tenant = account
    SubclassedProject.create!(name: "one", user_defined_scope: "taken")

    expect(SubclassedProject.new(name: "two", user_defined_scope: "taken")).not_to be_valid
    ActsAsTenant.current_tenant = accounts(:bar)
    expect(SubclassedProject.new(name: "two", user_defined_scope: "taken")).to be_valid
  ensure
    ActsAsTenant.set_tenant_klass(previous_tenant_klass)
  end

  it "handles user defined scopes" do
    UniqueTask.create!(name: "foo", user_defined_scope: "unique_scope")
    expect(UniqueTask.create(name: "foo", user_defined_scope: "another_scope")).to be_valid
    expect(UniqueTask.create(name: "foo", user_defined_scope: "unique_scope")).not_to be_valid
  end

  it "validates the uniqueness of multiple fields" do
    ActsAsTenant.current_tenant = account
    MultiFieldUniqueTask.create!(name: "foo", user_defined_scope: "bar")

    expect(MultiFieldUniqueTask.new(name: "foo", user_defined_scope: "baz")).not_to be_valid
    expect(MultiFieldUniqueTask.new(name: "baz", user_defined_scope: "bar")).not_to be_valid
    expect(MultiFieldUniqueTask.new(name: "baz", user_defined_scope: "baz")).to be_valid

    ActsAsTenant.current_tenant = accounts(:bar)
    expect(MultiFieldUniqueTask.new(name: "foo", user_defined_scope: "bar")).to be_valid
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

    it "keeps the current tenant when called without a block" do
      ActsAsTenant.current_tenant = account

      expect { ActsAsTenant.with_tenant(accounts(:bar)) }.to raise_error(ArgumentError)
      expect { ActsAsTenant.without_tenant }.to raise_error(ArgumentError)
      expect(ActsAsTenant.current_tenant).to eq(account)
    end

    it "does not bleed test_tenant into current_tenant" do
      ActsAsTenant.current_tenant = nil
      ActsAsTenant.test_tenant = account

      ActsAsTenant.with_tenant(accounts(:bar)) {}

      ActsAsTenant.test_tenant = nil
      expect(ActsAsTenant.current_tenant).to eq(nil)
    end

    it "does not bleed default_tenant into current_tenant" do
      old_default_tenant = ActsAsTenant.default_tenant
      ActsAsTenant.default_tenant = account

      ActsAsTenant.with_tenant(accounts(:bar)) {}

      ActsAsTenant.default_tenant = nil
      expect(ActsAsTenant.current_tenant).to eq(nil)
    ensure
      ActsAsTenant.default_tenant = old_default_tenant
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

    it "should set test_tenant to nil inside the block" do
      ActsAsTenant.test_tenant = account
      ActsAsTenant.without_tenant do
        expect(ActsAsTenant.test_tenant).to be_nil
      end
    end

    it "should set test_tenant to nil even if default_tenant is set" do
      old_default_tenant = ActsAsTenant.default_tenant
      ActsAsTenant.default_tenant = Account.create!(name: "foo")
      ActsAsTenant.without_tenant do
        expect(ActsAsTenant.test_tenant).to be_nil
      end
    ensure
      ActsAsTenant.default_tenant = old_default_tenant
    end

    it "should reset test_tenant to the previous tenant once exiting the block" do
      ActsAsTenant.test_tenant = account
      ActsAsTenant.without_tenant {}
      expect(ActsAsTenant.test_tenant).to eq(account)
    end

    it "does not bleed test_tenant into current_tenant" do
      ActsAsTenant.current_tenant = nil
      ActsAsTenant.test_tenant = account

      ActsAsTenant.without_tenant {}

      ActsAsTenant.test_tenant = nil
      expect(ActsAsTenant.current_tenant).to eq(nil)
    end

    it "does not bleed default_tenant into current_tenant" do
      old_default_tenant = ActsAsTenant.default_tenant
      ActsAsTenant.default_tenant = account

      ActsAsTenant.without_tenant {}

      ActsAsTenant.default_tenant = nil
      expect(ActsAsTenant.current_tenant).to eq(nil)
    ensure
      ActsAsTenant.default_tenant = old_default_tenant
    end

    it "should return the value of the block" do
      value = ActsAsTenant.without_tenant { "something" }
      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.without_tenant }.to raise_error(ArgumentError, /block required/)
    end
  end

  describe "::with_mutable_tenant" do
    it "should return the value of the block" do
      value = ActsAsTenant.with_mutable_tenant { "something" }
      expect(value).to eq "something"
    end

    it "should raise an error when no block is provided" do
      expect { ActsAsTenant.with_mutable_tenant }.to raise_error(ArgumentError, /block required/)
    end

    it "should set tenant back to immutable after the block" do
      ActsAsTenant.with_mutable_tenant do
        "something"
      end
      expect(ActsAsTenant.mutable_tenant?).to eq false
    end

    it "should keep the tenant mutable after a nested block" do
      ActsAsTenant.with_mutable_tenant do
        ActsAsTenant.with_mutable_tenant { "something" }
        expect(ActsAsTenant.mutable_tenant?).to eq true
      end
      expect(ActsAsTenant.mutable_tenant?).to eq false
    end

    it "should not make the tenant mutable in other threads" do
      ActsAsTenant.with_mutable_tenant do
        expect(Thread.new { ActsAsTenant.mutable_tenant? }.value).to eq false
      end
    end

    describe "mutability" do
      before do
        @account = Account.create!(name: "foo")
        @project = @account.projects.create!(name: "bar")
      end

      it "should allow tenant_id to change inside the block" do
        new_account_id = @account.id + 1
        expect { ActsAsTenant.with_mutable_tenant { @project.account_id = new_account_id } }.to_not raise_error
        expect(@project.account_id).to eq new_account_id
      end
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
  end
end
