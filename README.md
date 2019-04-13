Acts As Tenant
==============

[![Build Status](https://travis-ci.org/ErwinM/acts_as_tenant.svg)](https://travis-ci.org/ErwinM/acts_as_tenant)

**Note**: acts_as_tenant was introduced in this [blog post](https://github.com/ErwinM/acts_as_tenant/blob/master/docs/blog_post.md).

This gem was born out of our own need for a fail-safe and out-of-the-way manner to add multi-tenancy to our Rails app through a shared database strategy, that integrates (near) seamless with Rails.

acts_as_tenant adds the ability to scope models to a tenant. Tenants are represented by a tenant model, such as `Account`. acts_as_tenant will help you set the current tenant on each request and ensures all 'tenant models' are always properly scoped to the current tenant: when viewing, searching and creating.

In addition, acts_as_tenant:

* sets the current tenant using the subdomain or allows you to pass in the current tenant yourself
* protects against various types of nastiness directed at circumventing the tenant scoping
* adds a method to validate uniqueness to a tenant, `validates_uniqueness_to_tenant`
* sets up a helper method containing the current tenant

Installation
------------
acts_as_tenant will only work on Rails 3.1 and up. This is due to changes made to the handling of `default_scope`, an essential pillar of the gem.

To use it, add it to your Gemfile:

```ruby
gem 'acts_as_tenant'
```

Getting started
===============
There are two steps in adding multi-tenancy to your app with acts_as_tenant:

1. setting the current tenant and
2. scoping your models.

Setting the current tenant
--------------------------
There are three ways to set the current tenant:

1. by using the subdomain to lookup the current tenant,
2. by setting  the current tenant in the controller, and
3. by setting the current tenant for a block.

### Use the subdomain to lookup the current tenant ###

```ruby
class ApplicationController < ActionController::Base
  set_current_tenant_by_subdomain(:account, :subdomain)
end
```

This tells acts_as_tenant to use the current subdomain to identify the current tenant. In addition, it tells acts_as_tenant that tenants are represented by the Account model and this model has a column named 'subdomain' which can be used to lookup the Account using the actual subdomain. If ommitted, the parameters will default to the values used above.

Alternatively, you could locate the tenant using the method `set_current_tenant_by_subdomain_or_domain( :account, :subdomain,  :domain )` which will try to match a record first by subdomain. in case it fails, by domain.

### Setting the current tenant in a controller, manually ###

```ruby
class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :your_method_that_finds_the_current_tenant

  def your_method_that_finds_the_current_tenant
    current_account = Account.find_it
    set_current_tenant(current_account)
  end
end
```

Setting the `current_tenant` yourself, requires you to declare `set_current_tenant_through_filter` at the top of your application_controller to tell acts_as_tenant that you are going to use a before_action to setup the current tenant. Next you should actually setup that before_action to fetch the current tenant and pass it to `acts_as_tenant` by using `set_current_tenant(current_tenant)` in the before_action.


### Setting the current tenant for a block ###

```ruby
ActsAsTenant.with_tenant(current_account) do
  # Current tenant is set for all code in this block
end
```

This approach is useful when running background processes for a specified tenant. For example, by putting this in your worker's run method,
any code in this block will be scoped to the current tenant. All methods that set the current tenant are thread safe.

**Note:** If the current tenant is not set by one of these methods, Acts_as_tenant will be unable to apply the proper scope to your models. So make sure you use one of the two methods to tell acts_as_tenant about the current tenant.

### Disabling tenant checking for a block ###

```ruby
ActsAsTenant.without_tenant do
  # Tenant checking is disabled for all code in this block
end
```
This is useful in shared routes such as admin panels or internal dashboards when `require_tenant` option is enabled throughout the app.

### Require tenant to be set always ###

If you want to require the tenant to be set at all times, you can configure acts_as_tenant to raise an error when a query is made without a tenant available. See below under configuration options.

Scoping your models
-------------------

```ruby
class AddAccountToUsers < ActiveRecord::Migration
  def up
    add_column :users, :account_id, :integer
    add_index  :users, :account_id
  end
end

class User < ActiveRecord::Base
  acts_as_tenant(:account)
end
```

`acts_as_tenant` requires each scoped model to have a column in its schema linking it to a tenant. Adding `acts_as_tenant` to your model declaration will scope that model to the current tenant **BUT ONLY if a current tenant has been set**.

Some examples to illustrate this behavior:

```ruby
# This manually sets the current tenant for testing purposes. In your app this is handled by the gem.
ActsAsTenant.current_tenant = Account.find(3)

# All searches are scoped by the tenant, the following searches will only return objects
# where account_id == 3
Project.all =>  # all projects with account_id => 3
Project.tasks.all #  => all tasks with account_id => 3

# New objects are scoped to the current tenant
@project = Project.new(:name => 'big project')    # => <#Project id: nil, name: 'big project', :account_id: 3>

# It will not allow the creation of objects outside the current_tenant scope
@project.account_id = 2
@project.save                                     # => false

# It will not allow association with objects outside the current tenant scope
# Assuming the Project with ID: 2 does not belong to Account with ID: 3
@task = Task.new  # => <#Task id: nil, name: nil, project_id: nil, :account_id: 3>
```

Acts_as_tenant uses Rails' `default_scope` method to scope models. Rails 3.1 changed the way `default_scope` works in a good way. A user defined `default_scope` should integrate seamlessly with the one added by `acts_as_tenant`.

### Validating attribute uniqueness ###

If you need to validate for uniqueness, chances are that you want to scope this validation to a tenant. You can do so by using:

```ruby
validates_uniqueness_to_tenant :name, :email
```

All options available to Rails' own `validates_uniqueness_of` are also available to this method.

### Custom foreign_key ###

You can explicitely specifiy a foreign_key for AaT to use should the key differ from the default:

```ruby
acts_as_tenant(:account, :foreign_key => 'accountID) # by default AaT expects account_id
```

Configuration options
---------------------
An initializer can be created to control (currently one) option in ActsAsTenant. Defaults
are shown below with sample overrides following. In `config/initializers/acts_as_tenant.rb`:

```ruby
ActsAsTenant.configure do |config|
  config.require_tenant = false # true
end
```

* `config.require_tenant` when set to true will raise an ActsAsTenant::NoTenant error whenever a query is made without a tenant set.

Sidekiq support
---------------

ActsAsTenant supports [Sidekiq](http://sidekiq.org/). A background processing library.
Add the following code to your `config/initializers/acts_as_tenant.rb`:

```ruby
require 'acts_as_tenant/sidekiq'
```

Testing
---------------

If you set the `current_tenant` in your tests, make sure to clean up the tenant after each test by calling `ActsAsTenant.current_tenant = nil`. Integration tests are more difficult: manually setting the `current_tenant` value will not survive across multiple requests, even if they take place within the same test. This can result in undesired boilerplate to set the desired tenant. Moreover, the efficacy of the test can be compromised because the set `current_tenant` value will carry over into the request-response cycle.

To address this issue, ActsAsTenant provides for a `test_tenant` value that can be set to allow for setup and post-request expectation testing. It should be used in conjunction with middleware that clears out this value while an integration test is processing. A typical Rails and RSpec setup might look like:

```ruby
# test.rb
require_dependency 'acts_as_tenant/test_tenant_middleware'

Rails.application.configure do
  config.middleware.use ActsAsTenant::TestTenantMiddleware
end
```

```ruby
# spec_helper.rb
config.before(:suite) do
  # Make the default tenant globally available to the tests
  $default_account = Account.create!
end

config.before(:each) do
  if example.metadata[:type] == :request
    # Set the `test_tenant` value for integration tests
    ActsAsTenant.test_tenant = $default_account
  else
    # Otherwise just use current_tenant
    ActsAsTenant.current_tenant = $default_account
  end
end

config.after(:each) do
  # Clear any tenancy that might have been set
  ActsAsTenant.current_tenant = nil
  ActsAsTenant.test_tenant = nil
end
```

To Do
-----
* ...

Bug reports & suggested improvements
------------------------------------
If you have found a bug or want to suggest an improvement, please use our issue tracked at:

[github.com/ErwinM/acts_as_tenant/issues](http://github.com/ErwinM/acts_as_tenant/issues)

If you want to contribute, fork the project, code your improvements and make a pull request on [Github](http://github.com/ErwinM/acts_as_tenant/). When doing so, please don't forget to add tests. If your contribution is fixing a bug it would be perfect if you could also submit a failing test, illustrating the issue.

Author & Credits
----------------
acts_as_tenant is written by Erwin Matthijssen.

This gem was inspired by Ryan Sonnek's [Multitenant](https://github.com/wireframe/multitenant) gem and its use of default_scope.

License
-------
Copyright (c) 2011 Erwin Matthijssen, released under the MIT license
