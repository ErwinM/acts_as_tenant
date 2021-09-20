<h2> Adding multi-tenancy to your Rails app: acts_as_tenant </h2>
Roll Call is implemented as a multi-tenant application: each user gets their own instance of the app, content is strictly scoped to a user&#8217;s instance. In Rails, this can be achieved in various ways. Guy Naor did a great job of diving into the pros and cons of each option in his <a href="https://www.youtube.com/watch?v=0QstBE0Bfj8">2009 Acts As Conference talk</a>. If you are doing multi-tenancy in Rails, you should watch his video.</p>
<p>With a multi-db or multi-schema approach, you only deal with the multi-tenancy-aspect in a few specific spots in your app (Jerod Santo recently wrote an excellent post on implementing a <a href="http://blog.jerodsanto.net/2011/07/building-multi-tenant-rails-apps-with-postgresql-schemas/">multi-schema strategy</a>). Compared to the previous two strategies, a <strong>shared database</strong> strategy has the downside that the &#8216;multi-tenancy&#8217;-logic is something you need to actively be aware of and manage in almost every part of your app.</p>
<h4>Using a Shared Database strategy is alot of work!</h4>
<p>For various other reasons we opted for a <strong>shared database</strong> strategy. However, for us the prospect of dealing with the multi-tenancy-logic throughout our app, was not appealing. Worse, we run the risk of accidently exposing content of one tenant to another one, if we mismanage this logic. While researching this topic I noticed there are no real ready made solutions available that get you on your way, <a href="http://github.com/wireframe/multitenant">Ryan Sonnek</a> wrote his &#8216;multitenant&#8217; gem and <a href="http://github.com/mconnell/multi_tenant">Mark Connel</a> did the same. Neither of these solution seemed &#8220;finished&#8221; to us. So, we wrote our own implementation.</p>
<h4>First, how does multi-tenancy with a shared database strategy work</h4>
<p>A shared database strategy manages the multi-tenancy-logic through Rails associations. A tenant is represented by an object, for example an <code>Account</code>. All other objects are associated with a tenant: <code>belongs_to :account</code>. Each request starts with finding the <code>@current_account</code>. After that, each find is scoped through the tenant object: <code>current_account.projects.all</code>. This has to be remembered everywhere: in model method declarations and in controller actions. Otherwise, you&#8217;re exposing content of other tenants.</p>
<p>In addition, you have to actively babysit other parts of your app: <code>validates_uniqueness_of</code> requires you to scope it to the current tenant. You also have to protect agaist all sorts of form-injections that could allow one tenant to gain access or temper with the content of another tenant (see <a href="http://www.slideshare.net/tardate/multitenancy-with-rails">Paul Gallaghers</a> presentation for more on these dangers).</p>
<h4>Enter acts_as_tenant</h4>
<p>I wanted to implement all the concerns above in an easy to manage, out of the way fashion. We should be able to add a single declaration to our model and that should implement:</p>
<ol>
	<li>scoping all searches to the current <code>Account</code></li>
	<li>scoping the uniqueness validator to the current <code>Account</code></li>
	<li>protecting against various nastiness trying to circumvent the scoping.</li>
</ol>
<p>The result is <code>acts_as_tenant</code> (<a href="https://github.com/ErwinM/acts_as_tenant">github</a>), a rails gem that will add multi tenancy using a shared database to your rails app in an out-of-your way fashion.</p>
<p>In the <span class="caps">README</span>, you will find more information on using <code>acts_as_tenant</code> in your projects, so we&#8217;ll give you a high-level overview here. Let&#8217;s suppose that you have an app to which you want to add multi tenancy, tenants are represented by the <code>Account</code> model and <code>Project</code> is one of the models that should be scoped by tenant:</p>

```ruby
  class Addaccounttoproject < ActiveRecord::Migration
    def change
      add_column :projects, :account_id, :integer
    end
  end

  class Project < ActiveRecord::Base
    acts_as_tenant(:account)
    validates_uniqueness_to_tenant :name
  end
```
What does adding these two methods accomplish:
<ol>
	<li>it ensures every search on the project model will be scoped to the current tenant,</li>
	<li>it adds validation for every association confirming the associated object does indeed belong to the current tenant,</li>
	<li>it validates the uniqueness of `:name` to the current tenant,</li>
	<li>it implements a bunch of safeguards preventing all kinds of nastiness from exposing other tenants data (mainly form-injection attacks).</li>
</ol>
<p>Of course, all the above assumes `acts_as_tenant` actually knows who the current tenant is. Two strategies are implemented to help with this.</p>
<p><strong>Using the subdomain to workout the current tenant</strong></p>

```ruby
  class ApplicationController < ActionController::Base
    set_current_tenant_by_subdomain(:account, :subdomain)
  end
```
<p>Adding the above method to your `application_controller` tells `acts_as_tenant`:</p>
<ol>
	<li>the current tenant should be found based on the subdomain (e.g. account1.myappdomain.com),</li>
	<li>tenants are represented by the `Account`-model and</li>
	<li>the `Account` model has a column named `subdomain` that should be used the lookup the current account, using the current subdomain.</li>
</ol>
<p><strong>Passing the current account to acts_as_tenant yourself</strong></p>

```ruby
  class ApplicationController < ActionController::Base
    current_account = Account.method_to_find_the_current_account
    set_current_tenant_to(current_account)
  end
```
<p>`Acts_as_tenant` also adds a handy helper to your controllers `current_tenant`, containing the current tenant object.</p>
<h4>Great! Anything else I should know? A few caveats:</h4>
<ul>
	<li>scoping of models *only* works if `acts_as_tenant` has a current_tenant available. If you do not set one by one of the methods described above, *no scope* will be applied!</li>
	<li>for validating uniqueness within a tenant scope you must use the `validates_uniqueness_to_tenant`method. This method takes all the options the regular `validates_uniqueness_of` method takes.</li>
	<li>it is probably best to add the `acts_as_tenant` declaration after any other `default_scope` declarations you add to a model (I am not exactly sure how rails 3 handles the chaining. If someone can enlighten me, thanks!).</li>
</ul>
<p>We have been testing <a href="https://github.com/ErwinM/acts_as_tenant">acts_as_tenant</a> within Roll Call during recent weeks and it seems to be behaving well. Having said that, we welcome any feedback. This is my first real attempt at a plugin and the possibility of various improvements is almost a given.</p>
