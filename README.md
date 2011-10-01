Acts As Tenant
==============
This gem was born out of our own need for a fail-safe and out-of-the-way manner to add multi-tenancy to a Rails app with a shared database scheme, that integrates (near) seamless with Rails.

Acts_As_Tenant adds the ability to scope models to a tenant model, such as an account. Acts_As_Tenant will set the current tenant for you and ensures all 'tenant models' are always properly scoped to the current tenant: when viewing, searching and creating.

In addition, Acts_As_Tenant:
* sets the current tenant using the subdomain or allows you to pass in the current tenant yourself
* ensures scoping even in unusual usage cases, such as parameter manipulation
* adds support for multi-tenancy to Rails' uniqueness validator, validates_uniqueness_of
* sets up a helper method containing the current tenant

Installation
------------
Acts_As_Tenant will only work on Rails 3.1 and up. This is due to changes made to the handling of default_scope, an essential pillar of the gem.

To use it, add it to your Gemfile:
  
    gem 'acts_as_tenant'
  
Getting started
===============
There are two steps in adding multi-tenancy to your app with acts_as_tenant: (1) setting the current tenant  and (2) scoping your models.

Setting the current tenant
--------------------------
There are two ways to set the current tenant: (1) by using the subdomain to lookup the current tenant and (2) by passing in the current tenant yourself.

**Use the subdomain to lookup the current tenant**

    class ApplicationController < ActionController::Base
      set_current_tenant_by_subdomain(:account, :subdomain)
    end
This tells Acts_As_Tenant to use the current subdomain to identify the current tenant. In addition, it tells Acts_As_Tenant that tenants are represented by the Account model and the subdomain can be found in the 'subdomain' column within the Account model. If ommitted they will default to these values.

**OR Pass in the current tenant yourself**

    class ApplicationController < ActionController::Base
      current_account = Account.find_the_current_account
      set_current_tenant_to(current_account)
    end
This allows you to pass in the current tenant yourself.

If the current tenant is not set by either of these methods, Acts_as_tenant will be unable to apply the proper scope to your models. So make sure you use one of the two methods to tell acts_as_tenant about the current tenant.
  
Scoping your models
-------------------
    class Addaccounttousers < ActiveRecord::Migration
      def up
        add_column :users, :account_id, :integer
      end
  
    class User < ActiveRecord::Base
      acts_as_tenant(:account)
    end
  
Acts_As_Tenant requires each scoped model to have a column in its schema linking it to a tenant. Adding acts_as_tenant to your model declaration will scope that model to the current tenant **if a current tenant has been set**.
  Acts_As_Tenant.current_tenant = Account.find(3)   
  
  # New objects are scoped to the current tenant
  @project = Project.new(:name => 'big project')    # => <#Project id: nil, name: 'big project', :account_id: 3>
  
  # It will not allow the creation of scoped objects 
  # linked to other than the current tenant
  @project.account_id = 2
  @project.save                                     # => false 
  
  
  



=== Configuring Application Controller


=== Configuring Models
* validates uniqueness of limitation

=== To Do

=== Bug reports & suggested improvements


=== Maintained by

=== Credits
This gem used the Multitenant gem by Ryan Sonnek as a starting point and some of his code to set the default_scope is reused.

== License
Copyright (c) 2011 Erwin Matthijssen, released under the MIT license
