Unreleased
----------

### Upgrading

These changes can make previously passing code or tests fail:

* When no tenant is set, a `belongs_to` association to a record from a different tenant than the record itself now fails validation. This affects admin tools, scripts and test factories that build records for mismatched tenants. [#367](https://github.com/ErwinM/acts_as_tenant/pull/367)
* `belongs_to` associations declared after `acts_as_tenant` are now validated against the current tenant, so assigning another tenant's record to them fails validation. [#363](https://github.com/ErwinM/acts_as_tenant/pull/363)
* ActiveJob resolves the tenant when the job is performed instead of when it's deserialized, and restores the previous tenant afterwards. [#358](https://github.com/ErwinM/acts_as_tenant/pull/358)
* `with_tenant` and `without_tenant` restore `current_tenant` to exactly what it was, without copying `test_tenant` or `default_tenant` into it. [#337](https://github.com/ErwinM/acts_as_tenant/pull/337)
* Polymorphic tenant types are written with `polymorphic_name`. For STI tenants this is the base class instead of the subclass. Existing rows are still found, but can be updated with `Comment.where(commentable_type: "FeaturedArticle").update_all(commentable_type: "Article")`. Matching the old class name will be removed in 2.0. [#369](https://github.com/ErwinM/acts_as_tenant/pull/369)
* `mutable_tenant!` is stored per request or job in `ActsAsTenant::Current` instead of globally, so calling `ActsAsTenant.mutable_tenant!(true)` once (e.g. in an initializer) no longer makes tenants mutable everywhere. Use `ActsAsTenant.with_mutable_tenant { ... }` instead. [#368](https://github.com/ErwinM/acts_as_tenant/pull/368)
* `config.require_tenant` callables are only called when no tenant is set and the query isn't inside `without_tenant`, instead of on every query. [#370](https://github.com/ErwinM/acts_as_tenant/pull/370)

### Changes

* Document using `CurrentAttributes` to access the request in a `require_tenant` lambda. [#299](https://github.com/ErwinM/acts_as_tenant/issues/299)
* Document which queries aren't scoped to the current tenant. [#354](https://github.com/ErwinM/acts_as_tenant/issues/354)
* Document setting the tenant in `sidekiq_retries_exhausted`, and remove the Sidekiq middleware check for `RetryJobs`, which was removed in Sidekiq 5. [#356](https://github.com/ErwinM/acts_as_tenant/issues/356)
* Fix `validates_uniqueness_to_tenant` using the tenant of whichever model last called `acts_as_tenant`, which raised `NoMethodError` or scoped by the wrong column when models use different tenant names, e.g. when it's called in a subclass. [#372](https://github.com/ErwinM/acts_as_tenant/pull/372)
* Fix `validates_uniqueness_to_tenant` raising `TypeError` when given multiple fields, like `validates_uniqueness_to_tenant :email, :username`. [#292](https://github.com/ErwinM/acts_as_tenant/issues/292)
* Fix `belongs_to` validation looking up the associated record by the owner's primary key instead of the associated model's, which failed when either used a primary key other than `id`. [#370](https://github.com/ErwinM/acts_as_tenant/pull/370)
* `with_tenant`, `without_tenant` and `with_mutable_tenant` no longer clear the current tenant when called without a block. They still raise `ArgumentError`. [#370](https://github.com/ErwinM/acts_as_tenant/pull/370)
* Validate that `belongs_to` associations belong to the record's tenant when no current tenant is set. [#367](https://github.com/ErwinM/acts_as_tenant/pull/367)
* Store polymorphic tenant types with `polymorphic_name`, matching Rails, so STI tenants can find their records through `has_many` associations. Records saved with the tenant's class name are still scoped to the tenant. [#369](https://github.com/ErwinM/acts_as_tenant/pull/369)
* `with_mutable_tenant` is now thread-safe and restores the previous mutability when nested. [#368](https://github.com/ErwinM/acts_as_tenant/pull/368)
* Fix polymorphic tenant id being set to the tenant's class name (saved as `0`) for records built before the current tenant was set. [#365](https://github.com/ErwinM/acts_as_tenant/pull/365)
* Document setting the current tenant in ActionCable with `around_command`. [#366](https://github.com/ErwinM/acts_as_tenant/pull/366)
* `with_tenant` and `without_tenant` no longer copy `test_tenant` or `default_tenant` into `current_tenant` when restoring it. [#337](https://github.com/ErwinM/acts_as_tenant/pull/337)
* Validate `belongs_to` associations declared after `acts_as_tenant`. Previously these were not checked for cross-tenant records. [#363](https://github.com/ErwinM/acts_as_tenant/pull/363)
* `config.require_tenant` callables can accept the relation being queried as an argument. [#362](https://github.com/ErwinM/acts_as_tenant/pull/362)

  ```ruby
  ActsAsTenant.configure do |config|
    config.require_tenant = lambda do |relation|
      relation.klass.name != "User"
    end
  end
  ```

* Add support for Rails 7.2, 8.0, 8.1 and Sidekiq 8. [#361](https://github.com/ErwinM/acts_as_tenant/pull/361)
* Resolve the tenant when performing a job instead of when deserializing it. [#358](https://github.com/ErwinM/acts_as_tenant/pull/358)

  Deserializing a job no longer loads the tenant record, so a job dashboard can list a job whose tenant was deleted instead of raising `ActiveRecord::RecordNotFound`. Performing such a job still raises, and `discard_on ActiveRecord::RecordNotFound` can now handle it. The tenant is set for the duration of `perform` and restored afterwards.

* Add `config.tenant_change_hook`, called with the new tenant whenever `current_tenant` is set and with `nil` when Rails resets it at the end of a request or job. It accepts any callable. [#333](https://github.com/ErwinM/acts_as_tenant/pull/333)

  This can be used to implement Postgres's row-level security, for example:

  ```ruby
  ActsAsTenant.configure do |config|
    config.tenant_change_hook = lambda do |tenant|
      if tenant
        ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_array(["SET rls.account_id = ?", tenant.id]))
      else
        ActiveRecord::Base.connection.execute("RESET rls.account_id")
      end
    end
  end
  ```

1.0.1
-----

* Cast GID to string for job args #326

1.0.0
-----

* [Breaking] Drop Rails 5.2 support
* Set current_tenant with ActiveJob automatically #319
* Replace RequestStore dependency with CurrentAttributes. #313 - @excid3
* Add `scope` support to `acts_as_tenant :account, ->{ with_deleted }` #282 - @adrian-gomez
  The scope will be forwarded to `belongs_to`.
* Add `job_scope` configuration to customize how tenants are loaded in background jobs - @excid3
  This is helpful for situations like soft delete:

```ruby
ActsAsTenant.configure do |config|
  config.job_scope = ->{ with_deleted }
end
```

0.6.1
-----

* Add `touch` for `belongs_to` association #306

0.6.0
-----

* Add `ActsAsTenant.with_mutable_tenant` for allowing tenants to be changed within a block #230

0.5.3
-----

* Add support for Sidekiq 7 - @excid3
* Fix global record validations with existing scope #294 - @mikecmpbll

0.5.2
-----

* `test_tenant` uses current thread for parallel testing - @mikecmpbll
* Reset `test_tenant` in `with_tenant` - @hakimaryan
* Add `acts_as_tenant through:` option for HABTM - @scarhand
* Allow callable object (lambda, proc, block, etc) for `require_tenant` - @cmer

0.5.1
-----

* Use `klass` from Rails association instead of our own custom lookup - @bramjetten

0.5.0
-----

* Drop support for Rails 5.1 or earlier
* Add tests for Rails 5.2, 6.0, and Rails master
* Use standardrb
* Refactor controller extensions into modules
* Add `subdomain_lookup` option to change which subdomain is used - @excid3
* Unsaved tenant records will now return no records. #227 - @excid3
* Refactor test suite and use dummy Rails app - @excid3
* Remove tenant getter override. Fixes caching issues with association. - @bernardeli

0.4.4
-----
* Implement support for polymorphic tenant
* Ability to use acts_as_tenant with only ActiveRecord (no Rails)
* Allow setting of custom primary key
* Bug fixes

0.4.3
-----
* allow 'optional' relations
* Sidekiq fixes
* Replace all `before_filter` with `before_action` for Rails 5.1 compatibility

0.4.1
------
* Removed (stale, no longer working) MongoDB support; moved code to separate branch
* Added without_tenant option (see readme, thx duboff)

0.4.0
------
* (Sub)domain lookup is no longer case insensitive
* Added ability to use inverse_of (thx lowjoel)
* Added ability to disable tenant checking for a block (thx duboff)
* Allow for validation that associations belong to the tenant to reflect on associations which return an Array from `where` (thx ludamillion)

0.3.9
-----
* Added ability to configure a default tenant for testing purposes. (thx iangreenleaf)
* AaT will now accept a string for a tenant_id (thx calebthompson)
* Improvements to readme (thx stgeneral)

0.3.8
-----
* Added Mongoid compatibility [thx iangreenleaf]

0.3.7
-----
* Fix for proper handling of polymorphic associations (thx sol1dus)
* Fix fefault scope to generate correct sql when using database prefix (thx IgorDobryn)
* Added ability to specify a custom Primary Key (thx matiasdim)
* Sidekiq 3.2.2+ no longer supports Ruby 1.9. Locking Sidekiq in gemspec at 3.2.1.
* Update RSPEC to 3.0. Convert all specs (thx petergoldstein)
* support sidekiq 3 interface (thx davekaro)

0.3.6
-----
* Added method `set_current_tenant_by_subdomain_or_domain` (thx preth00nker)

0.3.5
-----
* Fix to degredation introduced after 3.1 that prevented tenant_id from being set during initialization (thx jorgevaldivia)

0.3.4
-----
* Fix to a bug introduced in 0.3.2

0.3.3
-----
* Support user defined foreign keys on scoped models

0.3.2
-----
* correctly support nested models with has_many :through (thx dexion)
* Support 'www.subdomain.example.com' (thx wtfiwtz)
* Support setting `tenant_id` on scoped models if the `tenant_id` is nil (thx Matt Wilson)

0.3.1
-----
* Added support for Rails 4

0.3.0
-----
* You can now raise an exception if a query on a scope model is made without a tenant set. Adding an initializer that sets config.require_tenant to true will accomplish this. See readme for more details.
* `ActsAsTenant.with_tenant` will now return the value of the block it evaluates instead of the original tenant. The original tenant is restored automatically.
* acts_as_tenant now raises standard errors which can be caught individually.
* `set_current_tenant_to`, which was deprecated some versions ago and could lead to weird errors, has been removed.


0.2.9
-----
* Added support for many-to-many associations (thx Nucleoid)

0.2.8
-----
* Added dependencies to gemspec (thx aaronrenner)
* Added the `ActsAsTenant.with_tenant` block method (see readme) (thx aaronrenner)
* Acts_as_Tenant is now thread safe (thx davide)

0.2.7
-----
* Changed the interface for passing in the current_tenant manually in the controller. `set_current_tenant_to` has been deprecated and replaced by `set_current_tenant_through_filter` declaration and the `set_current_tenant` method. See readme for details.

0.2.6
-----
* Fixed a bug with resolving the tenant model name (thx devton!)
* Added support for using relations: User.create(:account => Account.first) now works, while it wouldn't before (thx bnmrrs)

0.2.5
-----
* Added Rails 3.2 compatibility (thx nickveys!)

0.2.4
-----
* Added correct handling of child models that do not have their parent set (foreign key == nil)


0.2.3
-----
* Added support for models that declare a has_one relationships, these would error out in the previous versions.


0.2.2
-----
* Enhancements
  * Added support for aliased associations ( belongs_to :something, :class_name => 'SomethingElse'). In previous version these would raise an 'uninitialized constant' error.

0.2.1
-----
* Initial release
