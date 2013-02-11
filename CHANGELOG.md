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
