Acts As Tenant
==============

note: acts_as_tenant was introduced in [this](http://www.rollcallapp.com/blog/add) blog post.

This gem was born out of our own need for a fail-safe and out-of-the-way manner to add multi-tenancy to our Rails app through a shared database strategy, that integrates (near) seamless with Rails.

acts_as_tenant adds the ability to scope models to a tenant. Tenants are represented by a tenant model, such as `Account`. acts_as_tenant will help you set the current tenant on each request and ensures all 'tenant models' are always properly scoped to the current tenant: when viewing, searching and creating.

In addition, acts_as_tenant:

* sets the current tenant using the subdomain or allows you to pass in the current tenant yourself
* protects against various types of nastiness directed at circumventing the tenant scoping
* adds a method to validate uniqueness to a tenant, validates_uniqueness_to_tenant
* sets up a helper method containing the current tenant

Installation
------------
acts_as_tenant will only work on Rails 3.1 and up. This is due to changes made to the handling of default_scope, an essential pillar of the gem.

To use it, add it to your Gemfile:
  
    gem 'acts_as_tenant'
  
Getting started
===============
There are two steps in adding multi-tenancy to your app with acts_as_tenant:

1. setting the current tenant and 
2. scoping your models.

Setting the current tenant
--------------------------
There are two ways to set the current tenant: (1) by using the subdomain to lookup the current tenant and (2) by passing in the current tenant yourself.

**Use the subdomain to lookup the current tenant**

    class ApplicationController < ActionController::Base
      set_current_tenant_by_subdomain(:account, :subdomain)
    end
This tells acts_as_tenant to use the current subdomain to identify the current tenant. In addition, it tells acts_as_tenant that tenants are represented by the Account model and this model has a column named 'subdomain' which can be used to lookup the Account using the actual subdomain. If ommitted, the parameters will default to the values used above.

**OR Pass in the current tenant yourself**

    class ApplicationController < ActionController::Base
      current_account = Account.find_the_current_account
      set_current_tenant_to(current_account)
    end
This allows you to pass in the current tenant yourself.

**note:** If the current tenant is not set by either of these methods, Acts_as_tenant will be unable to apply the proper scope to your models. So make sure you use one of the two methods to tell acts_as_tenant about the current tenant.
  
Scoping your models
-------------------
    class Addaccounttousers < ActiveRecord::Migration
      def up
        add_column :users, :account_id, :integer
      end
  
    class User < ActiveRecord::Base
      acts_as_tenant(:account)
    end
  
acts_as_tenant requires each scoped model to have a column in its schema linking it to a tenant. Adding acts_as_tenant to your model declaration will scope that model to the current tenant **BUT ONLY if a current tenant has been set**.

Some examples to illustrate this behavior:

    # This manually sets the current tenant for testing purposes. In your app this is handled by the gem.
    acts_as_tenant.current_tenant = Account.find(3)   
    
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
    @task = Task.new  # => <#Task id: nil, name: bil, project_id: nil, :account_id: 3>

Acts_as_tenant uses Rails' default_scope method to scope models. Rails 3.1 changed the way default_scope works in a good way. A user defined default_scope should integrate seamlessly with the one added by acts_as_tenant.

To Do
-----
* Change the tests to Test::Unit so I can easily add some controller tests.

Bug reports & suggested improvements
------------------------------------
If you have found a bug or want to suggest an improvement, please use our issue tracked at:

[github.com/ErwinM/acts_as_tenant/issues](http://github.com/ErwinM/acts_as_tenant/issues)

If you want to contribute, fork the project, code your improvements and make a pull request on [Github](http://github.com/ErwinM/acts_as_tenant/). When doing so, please don't forget to add tests. If your contribution is fixing a bug it would be perfect if you could also submit a failing test, illustrating the issue.

Author & Credits
----------------
acts_as_tenant is written by Erwin Matthijssen.  
Erwin is currently busy developing [Roll Call](http://www.rollcallapp.com/ "Roll Call App").

This gem was inspired by Ryan Sonnek's [Multitenant](https://github.com/wireframe/multitenant) gem and its use of default_scope.

License
-------
Copyright (c) 2011 Erwin Matthijssen, released under the MIT license
