# Pundit Authorization - Step-by-Step Tutorial Guide

**A practical, hands-on guide to implementing authorization in your Rails app**

This tutorial expands on 8 critical topics with real examples from your blog application. Reference the `PUNDIT.md` file for foundational concepts.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Topic 1: Handling Pundit::NotAuthorizedError](#topic-1-handling-punditnotauthorizederror)
3. [Topic 2: Custom Error Messages Per Action](#topic-2-custom-error-messages-per-action)
4. [Topic 3: Policy Scopes for Filtering Records](#topic-3-policy-scopes-for-filtering-records)
5. [Topic 4: Scope Class Implementation](#topic-4-scope-class-implementation)
6. [Topic 5: Using policy_scope in Controllers](#topic-5-using-policy_scope-in-controllers)
7. [Topic 6: Headless Policies (Policies Without Model)](#topic-6-headless-policies-policies-without-model)
8. [Topic 7: Displaying Elements Conditionally in Views](#topic-7-displaying-elements-conditionally-in-views)
9. [Topic 8: Using policy(@post).update? in Views](#topic-8-using-policypostupdate-in-views)
10. [Complete Workflow Example](#complete-workflow-example)

---

## Prerequisites

Before starting this tutorial, ensure you have:

```ruby
# Gemfile
gem 'pundit', '~> 2.3'
gem 'devise'  # For authentication
```

```bash
bundle install
rails generate pundit:install
```

---

## Topic 1: Handling Pundit::NotAuthorizedError

### What is Pundit::NotAuthorizedError?

When a user tries to perform an unauthorized action, Pundit raises `Pundit::NotAuthorizedError`. Your app needs to catch this error and respond gracefully.

### Step 1: Set Up Global Error Handler

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  helper PunditHelper

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    # Handle both HTML and JSON requests
    respond_to do |format|
      format.html do
        flash[:alert] = "You are not authorized"
        redirect_to request.referrer || root_path
      end

      format.json do
        render json: { error: "Not authorized" }, status: :forbidden
      end
    end
  end
end
```

### Step 2: Understand When Errors Are Raised

In your controller, when you call `authorize`:

```ruby
class BlogsController < ApplicationController
  def destroy
    @blog = Blog.find(params[:id])
    authorize @blog  # ← This line raises error if not authorized
    @blog.destroy
    redirect_to blogs_path
  end
end
```

**What happens when reader tries to delete:**

1. `authorize @blog` is called
2. Pundit checks `BlogPolicy#destroy?`
3. Policy returns `false` (reader not authorized)
4. `Pundit::NotAuthorizedError` is raised
5. `rescue_from` catches it
6. `user_not_authorized` is called
7. User sees flash message and redirects

### Step 3: Customize Error Responses

For different controllers, you can customize error handling:

```ruby
class BlogsController < ApplicationController
  rescue_from Pundit::NotAuthorizedError, with: :blog_not_authorized

  private

  def blog_not_authorized(exception)
    flash[:alert] = "You cannot modify this blog"
    redirect_to blogs_path
  end
end
```

### Real Project Flow

```
GET /blogs/1/destroy (reader user)
    ↓
BlogsController#destroy
    ↓
authorize @blog
    ↓
BlogPolicy#destroy? returns false
    ↓
Pundit::NotAuthorizedError raised
    ↓
rescue_from catches it
    ↓
flash[:alert] = "You are not authorized"
redirect_to referrer
    ↓
User sees message and stays on previous page
```

---

## Topic 2: Custom Error Messages Per Action

### The Problem: Generic Messages Aren't Helpful

```
"You are not authorized"  ← Doesn't explain WHY!
```

### The Solution: Explain the Reason

```
"Only blog owners can edit this blog"
"You must be an author to create blogs"
"Admins can only manage other users"
```

### Step 1: Add authorization_message to Policy

Implement `authorization_message(action)` that accepts the action being attempted:

```ruby
# app/policies/blog_policy.rb
class BlogPolicy < ApplicationPolicy
  def authorization_message(action = nil)
    case action
    when :show
      "This blog post is not available for viewing. Only published posts and your own drafts are visible."
    when :create, :new
      "You do not have permission to create blogs. Only authors and administrators can create posts."
    when :update, :edit
      "You can only edit your own blog posts. Administrators can edit any post."
    when :destroy
      "You can only delete your own blog posts. Administrators can delete any post."
    else
      "You are not authorized to perform this action on this blog."
    end
  end

  private

  def own_blog?
    record.user == user
  end
end
```

### Step 2: Update ApplicationController to Use Custom Messages

The error handler extracts the action name from the exception and passes it to the policy:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    # Extract the action name from the exception query method
    # e.g., "index?" becomes :index
    action = exception.query.to_s.gsub('?', '').to_sym if exception.query

    # Get the policy instance and custom message
    policy = exception.policy
    if policy && policy.respond_to?(:authorization_message)
      flash[:alert] = policy.authorization_message(action)
    else
      flash[:alert] = "You are not authorized to perform this action."
    end

    redirect_to(request.referrer || root_path)
  end
end
```

**How it works:**
- When `authorize @blog` fails on a destroy action, Pundit raises `NotAuthorizedError`
- The exception has `.query` set to `"destroy?"` and `.policy` with the policy instance
- Extract `:destroy` from `"destroy?"` by removing the `?` and converting to symbol
- Call `policy.authorization_message(:destroy)` to get the specific message
- Show user the contextual error message

### Step 3: Real Project Examples with Action-Specific Messages

```ruby
# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  def authorization_message(action = nil)
    case action
    when :index
      "You do not have permission to view the user list. Only administrators can access this."
    when :show
      if !user.present?
        "You must be logged in to view user details"
      elsif user.id != record.id && !user&.admin?
        "You can only view your own profile"
      else
        "You are not authorized to view this user"
      end
    when :edit, :update
      if !user.present?
        "You must be logged in to edit user details"
      elsif user.id != record.id && !user&.admin?
        "You can only edit your own profile"
      else
        "You are not authorized to edit this user"
      end
    when :assign_role
      if !user&.admin?
        "Only administrators can assign roles"
      else
        "You are not authorized to assign roles"
      end
    when :deactivate
      if !user&.admin?
        "Only administrators can deactivate users"
      elsif record.id == user.id
        "You cannot deactivate your own account"
      else
        "You are not authorized to deactivate this user"
      end
    when :activate
      if !user&.admin?
        "Only administrators can activate users"
      elsif record.id == user.id
        "You cannot activate your own account"
      else
        "You are not authorized to activate this user"
      end
    else
      "You are not authorized to perform this action on users"
    end
  end
end

# app/policies/admin_policy.rb (Headless)
class AdminPolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def authorization_message(action = nil)
    case action
    when :index
      "You do not have permission to access the admin dashboard. Only administrators can access this section."
    when :manage_users
      "You do not have permission to manage users. Only administrators can manage users."
    when :assign_role
      "You do not have permission to assign roles. Only administrators can assign roles."
    when :deactivate_user
      "You do not have permission to deactivate users. Only administrators can perform this action."
    when :activate_user
      "You do not have permission to activate users. Only administrators can perform this action."
    when :view_analytics
      "You do not have permission to view analytics. Only administrators can access this."
    else
      "You are not authorized to access this admin section."
    end
  end
end
```

### User Experience Improvement with Action-Specific Messages

**Before (Generic Message):**
```
Reader tries to create blog
↓
"You are not authorized to perform this action."
↓
User is confused - why can't I create?

Reader tries to view another's draft
↓
"You are not authorized to perform this action."
↓
User doesn't know why

Admin tries to deactivate own account
↓
"You are not authorized to perform this action."
↓
Admin doesn't know if it's a permission or role issue
```

**After (Action-Specific Messages):**
```
Reader tries to create blog
↓
"You do not have permission to create blogs. Only authors and administrators can create posts."
↓
User knows to ask admin for author role

Reader tries to view another's draft
↓
"This blog post is not available for viewing. Only published posts and your own drafts are visible."
↓
User understands the visibility rules

Admin tries to deactivate own account
↓
"You cannot deactivate your own account"
↓
Admin knows it's by design for safety
```

**How Exception Handler Maps Actions to Messages:**
```
User action         Exception.query    Extracted action    Message from policy
─────────────────   ────────────────   ────────────────    ────────────────────────
destroy blog        "destroy?"         :destroy            "You can only delete your own blog posts..."
edit user           "edit?"            :edit               "You can only edit your own profile"
create blog         "create?"          :create             "Only authors and administrators can create posts"
activate user       "activate?"        :activate           "You cannot activate your own account"
```

---

## Topic 3: Policy Scopes for Filtering Records

### The Critical Problem

Without scopes, you might expose data users shouldn't see:

```ruby
# ❌ SECURITY VULNERABILITY
def index
  @blogs = Blog.all
end

# Draft blogs visible to all users!
```

Scope problems manifest in multiple ways:
1. **Data Leakage** - Sensitive drafts/private data exposed to wrong users
2. **Information Disclosure** - Users can discover unpublished content
3. **Privacy Violation** - User lists, metadata, hidden records visible
4. **Compliance Issues** - GDPR/privacy law violations

### The Solution: Filter by Role

```ruby
# ✅ SECURE
def index
  @blogs = policy_scope(Blog)
end

# Readers see: only published
# Authors see: published + their own drafts
# Admins see: everything
```

Scope provides:
- **Automatic filtering** - Based on current user's role
- **Consistent behavior** - Same rules everywhere
- **Single point of change** - Update scope once, affects all queries
- **Safety by default** - More restrictive than permissive

### Step 1: Deep Dive: Understanding Scope Purpose

A scope automatically filters collections based on what the current user can see. It's NOT for individual record authorization - that's what `authorize` does.

**Key Distinction:**
```
authorize @blog          ← Check if user can perform action on THIS record
policy_scope(Blog)       ← Filter to show only records user CAN see
```

**Real-world analogy:**
```
Library with thousands of books:
- authorize checks: "Can THIS person check out THIS book?"
- policy_scope filters: "Show THIS person only the books they're allowed to see"
```

**Visual Comparison:**

```
WITHOUT SCOPE (❌ UNSAFE):
├── Reader sees all 5 blogs
│   ├── Published blog 1
│   ├── Published blog 2
│   ├── Draft blog 1  ← SHOULDN'T SEE THIS
│   ├── Draft blog 2  ← SHOULDN'T SEE THIS
│   └── Archive blog 1 ← SHOULDN'T SEE THIS

WITH SCOPE (✅ SAFE):
├── Reader sees 2 blogs (policy-scoped)
│   ├── Published blog 1
│   └── Published blog 2

├── Author sees 4 blogs (policy-scoped)
│   ├── Published blog 1
│   ├── Published blog 2
│   ├── Their own draft 1
│   └── Their own draft 2

├── Admin sees all 5 blogs (policy-scoped)
│   ├── Published blog 1
│   ├── Published blog 2
│   ├── Draft blog 1
│   ├── Draft blog 2
│   └── Archive blog 1
```

### Step 2: The Three-Step Scope Process

```
Step 1: Controller calls policy_scope(Blog)
           ↓
Step 2: Pundit creates BlogPolicy::Scope.new(current_user, Blog)
           ↓
Step 3: Calls scope.resolve
           ↓
Step 4: Returns filtered ActiveRecord scope
           ↓
Step 5: Controller can chain methods on result
```

### Step 3: See It In Action

```ruby
# app/controllers/blogs_controller.rb
class BlogsController < ApplicationController
  def index
    # Without scope - get ALL blogs (unsafe)
    # @blogs = Blog.all

    # With scope - get only authorized blogs (safe)
    @blogs = policy_scope(Blog).order(created_at: :desc)
  end
end
```

**Result for different users:**

```ruby
# Reader signs in
@blogs = policy_scope(Blog)
# Returns: [published_1, published_2]

# Author (who owns draft_1 and draft_2) signs in
@blogs = policy_scope(Blog)
# Returns: [published_1, draft_1, draft_2, published_2]

# Admin signs in
@blogs = policy_scope(Blog)
# Returns: [all 5 blogs - published, drafts, everything]

# Anonymous (not logged in)
@blogs = policy_scope(Blog)
# Returns: [published_1, published_2]
```

---

## Topic 4: Scope Class Implementation

### The Scope Class Structure

Every policy can have an inner `Scope` class that filters collections. The Scope class is separate from the policy because:
- It works with collections, not individual records
- It inherits from `ApplicationPolicy::Scope` which provides the structure
- The `resolve` method must always return an ActiveRecord scope, not an array

```ruby
class BlogPolicy < ApplicationPolicy
  # AUTHORIZATION: Check if user can perform action on individual record
  def update?
    own_blog? || user&.admin?
  end

  # FILTERING: Filter which records the user can see
  class Scope < ApplicationPolicy::Scope
    def initialize(user, scope)
      @user = user           # Current user
      @scope = scope         # The ActiveRecord scope (Blog, User, etc.)
    end

    def resolve
      # MUST return ActiveRecord scope (not array!)
      # This scope will be used in controllers:
      # @blogs = policy_scope(Blog).order(created_at: :desc)
      raise NotImplementedError
    end
  end
end
```

**What happens when you call policy_scope:**
```
controller: @blogs = policy_scope(Blog)
  ↓
Pundit: BlogPolicy::Scope.new(current_user, Blog).resolve
  ↓
Your resolve method returns: Blog.where(published: true)
  ↓
Controller gets: Blog.where(published: true) (still an ActiveRecord scope!)
  ↓
Can chain: @blogs.order(created_at: :desc).page(1)
```

### Step 1: Implement Basic Scope

```ruby
class BlogPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Everyone sees published blogs
      scope.where(published: true)
    end
  end
end
```

### Step 2: Add Role-Based Filtering

Role-based filtering uses conditional logic to return different results for different user types:

```ruby
class BlogPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Different filtering based on user role
      case user
      when nil
        # Guests (not logged in) see only published
        scope.where(published: true)

      when ->(u) { u.reader? }
        # Readers see only published blogs
        scope.where(published: true)

      when ->(u) { u.author? }
        # Authors see:
        # 1. Published blogs (everyone's)
        # 2. Their own drafts
        scope.where("published = true OR user_id = ?", user.id)

      when ->(u) { u.admin? }
        # Admins see all blogs regardless of status
        scope.all

      else
        # Fallback for unknown roles
        scope.where(published: true)
      end
    end
  end
end
```

**How the different results look in practice:**

Database has: 5 blogs (3 published, 2 drafts)

```
Anonymous user loads /blogs
  BlogPolicy::Scope.new(nil, Blog).resolve
  ↓ Returns: Blog.where(published: true)
  ↓ Result: [published_1, published_2, published_3] = 3 blogs

Reader user loads /blogs
  BlogPolicy::Scope.new(reader, Blog).resolve
  ↓ Returns: Blog.where(published: true)
  ↓ Result: [published_1, published_2, published_3] = 3 blogs

Author (owns 1 draft) loads /blogs
  BlogPolicy::Scope.new(author, Blog).resolve
  ↓ Returns: Blog.where("published = true OR user_id = ?", 42)
  ↓ Result: [published_1, published_2, published_3, their_draft_1] = 4 blogs

Admin loads /blogs
  BlogPolicy::Scope.new(admin, Blog).resolve
  ↓ Returns: Blog.all
  ↓ Result: [published_1, published_2, published_3, draft_1, draft_2] = 5 blogs
```

**Understanding the lambda syntax:**
```ruby
when ->(u) { u.reader? }
     └─ Lambda ─┘ └────────┘
        function  returns true if user is a reader

# Alternative (more explicit):
when ->(u) { u.role == 'reader' }

# Your case statement matches different TYPES of users
```

### Step 3: Critical Rule: Return Scope, Not Array

```ruby
# ✅ CORRECT - returns ActiveRecord scope
def resolve
  scope.where(published: true)
end

# ❌ WRONG - converts to array
def resolve
  scope.where(published: true).to_a  # BAD!
end

# Why? Controller chains methods:
@blogs = policy_scope(Blog).order(created_at: :desc)
#                          ^^^^^ needs scope
# If array, .order() fails!
```

### Step 4: Add Helper Methods

```ruby
class BlogPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      elsif author?
        author_scope
      elsif reader?
        scope.where(published: true)
      else
        scope.where(published: true)
      end
    end

    private

    def admin?
      user&.admin?
    end

    def author?
      user&.author?
    end

    def reader?
      user&.reader?
    end

    def author_scope
      scope.where("published = true OR user_id = ?", user.id)
    end
  end
end
```

### Step 5: Complex Scope with Multiple Conditions

```ruby
class BlogPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      elsif moderator?
        # Moderators see published + flagged for review
        scope.where("published = true")
          .or(scope.where(flagged_for_review: true))
      elsif author?
        # Authors see published + their own (any state)
        scope.where("published = true")
          .or(scope.where(user_id: user.id))
      else
        # Readers/anonymous see published and not archived
        scope.where(published: true)
          .where("archived_at IS NULL")
      end
    end

    private

    def admin?
      user&.admin?
    end

    def moderator?
      user&.moderator?
    end

    def author?
      user&.author?
    end
  end
end
```

---

## Topic 5: Using policy_scope in Controllers

### Step 1: Replace Model.all with policy_scope

```ruby
# app/controllers/blogs_controller.rb
class BlogsController < ApplicationController
  def index
    # OLD (unsafe):
    # @blogs = Blog.all

    # NEW (safe):
    @blogs = policy_scope(Blog).order(created_at: :desc)
  end
end
```

### Step 2: Chain Methods on policy_scope

Since policy_scope returns an ActiveRecord scope, you can chain methods:

```ruby
def index
  @blogs = policy_scope(Blog)
    .order(created_at: :desc)      # Order by date
    .includes(:user)                # Eager load user (prevent N+1)
    .page(params[:page])            # Pagination
    .per(10)                        # 10 per page
end

def search
  @blogs = policy_scope(Blog)
    .where("title LIKE ?", "%#{params[:q]}%")
    .order(created_at: :desc)
end
```

### Step 3: Real Project - User Profile Page

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :authenticate_user!

  def profile
    @user = current_user

    # Published blogs - still scoped for authorization
    @published_blogs = policy_scope(Blog)
      .published                    # Use Blog scope
      .where(user_id: @user.id)
      .order(created_at: :desc)

    # Draft blogs - still scoped
    @draft_blogs = policy_scope(Blog)
      .drafts
      .where(user_id: @user.id)
      .order(created_at: :desc)
  end
end
```

### Step 4: Real Project - Admin Users Index

```ruby
# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  def index
    # Admin sees all users
    # Regular users see only themselves (via scope)
    @users = policy_scope(User)
      .order(created_at: :desc)
      .page(params[:page])
  end
end

# UserPolicy scope:
class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all  # Admins see all
      else
        scope.where(id: user.id)  # Users see only themselves
      end
    end
  end
end
```

### Step 5: Common Patterns

```ruby
# Pattern 1: Get count
@total_blogs = policy_scope(Blog).count
# Reader: 5, Author: 10, Admin: 15

# Pattern 2: Find with scope (extra safety!)
@blog = policy_scope(Blog).find(params[:id])
# Raises RecordNotFound if not in authorized scope

# Pattern 3: Nested resources
@user = User.find(params[:user_id])
@blogs = policy_scope(Blog).where(user_id: @user.id)

# Pattern 4: Search and filter
@blogs = policy_scope(Blog)
  .where("title LIKE ?", "%#{params[:q]}%")
  .order(created_at: :desc)
```

---

## Topic 6: Headless Policies (Policies Without Model)

### What Are Headless Policies?

"Headless" means the policy doesn't protect a specific model/record. Instead, it protects system-wide actions or sections:

**Traditional policies** (have a model):
```
UserPolicy protects User records
  - Can you view THIS user?
  - Can you edit THIS user?

BlogPolicy protects Blog records
  - Can you delete THIS blog?
  - Can you publish THIS blog?
```

**Headless policies** (no specific model):
```
AdminPolicy protects admin section
  - Can you access admin dashboard?
  - Can you manage users (all of them)?
  - Can you view analytics?

DashboardPolicy protects dashboard features
  - Can you view your stats?
  - Can you access beta features?

FeaturePolicy protects features globally
  - Is dark mode enabled for this user?
  - Can this user access export?
```

### Use Cases for Headless Policies:

1. **Admin sections** - Access to admin panel, manage system
2. **Feature toggles** - Which features does user have access to?
3. **Global actions** - Actions that affect the system
4. **User preferences** - Should this page show for this user?
5. **Settings/Configuration** - Access to sensitive settings

### Step 1: Create a Headless Policy

The key difference from regular policies:
- `initialize(user)` takes only the user, not a record
- Set `@record = nil` explicitly
- Methods check global permissions, not record ownership

```ruby
# app/policies/admin_policy.rb
class AdminPolicy < ApplicationPolicy
  # Override initialize - note: no record parameter!
  def initialize(user)
    @user = user
    @record = nil  # No specific record being protected
  end

  # Each method checks if user can perform this admin action
  def dashboard?
    # Can user see admin dashboard?
    user&.admin?
  end

  def manage_users?
    # Can user manage any users?
    user&.admin?
  end

  def view_audit_logs?
    # Can user see all system logs?
    user&.admin?
  end

  def view_settings?
    # Can user access system settings?
    user&.admin? || user&.moderator?
  end

  def authorization_message(action = nil)
    case action
    when :dashboard
      "You do not have permission to access the admin dashboard."
    when :manage_users
      "You do not have permission to manage users."
    else
      "You are not authorized to access this admin section"
    end
  end
end
```

**Why use headless policies instead of just checking in the controller?**

```ruby
# ❌ BAD: Authorization logic scattered in controllers
class Admin::DashboardController < ApplicationController
  def index
    if !current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
      return
    end
    # ... load data
  end
end

# ✅ GOOD: Centralized authorization in policy
class Admin::DashboardController < ApplicationController
  def index
    authorize :admin, :dashboard?  # Consistent, reusable
    # ... load data
  end
end
```

Benefits:
- **Consistency** - All admin checks use same policy
- **Single source of truth** - Change once, affects everywhere
- **Testability** - Easy to test authorization logic
- **Reusability** - Same checks from views, controllers, helpers

### Step 2: Use in Controller

The syntax for headless policies is different - pass a symbol as the "record":

```ruby
# app/controllers/admin/dashboard_controller.rb
class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin

  def index
    @users_count = User.count
    @blogs_count = Blog.count
    @active_users = User.active.count
  end

  private

  def authorize_admin
    # Syntax: authorize :symbol, :method?
    # Pundit will:
    # 1. Look for AdminPolicy (inferred from symbol)
    # 2. Instantiate: AdminPolicy.new(current_user)
    # 3. Call: policy.dashboard?
    # 4. Raise error if false
    authorize :admin, :dashboard?
  end
end
```

**How Pundit resolves the symbol to policy:**
```
authorize :admin, :dashboard?
    ↓
Pundit infers: AdminPolicy (capitalize + add "Policy")
    ↓
Creates: AdminPolicy.new(current_user)
    ↓
Calls: policy.dashboard?
    ↓
If returns false: Raise Pundit::NotAuthorizedError
If returns true: Continue normally
```

**Alternative: Inline authorization**
```ruby
class Admin::DashboardController < ApplicationController
  def index
    authorize :admin, :dashboard?  # Can go directly in action too
    # ... rest of action
  end
end
```

**What happens if user is not authorized:**
```
User (not admin) tries to access /admin
    ↓
authorize :admin, :dashboard? runs
    ↓
AdminPolicy.new(user).dashboard? returns false
    ↓
Pundit::NotAuthorizedError raised
    ↓
ApplicationController#user_not_authorized catches it
    ↓
policy.authorization_message(:dashboard) returns custom message
    ↓
Flash message shown, redirected to referrer
```

### Step 3: Another Example - DashboardPolicy

```ruby
# app/policies/dashboard_policy.rb
class DashboardPolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def view?
    user.present?  # Must be logged in
  end

  def author_stats?
    user&.author? || user&.admin?
  end

  def analytics?
    user&.author? || user&.admin?
  end

  def settings?
    user.present?  # Any logged in user
  end
end

# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    authorize :dashboard, :view?
    @stats = calculate_stats if policy(:dashboard).author_stats?
  end
end
```

### Step 4: Feature Toggle Policy

```ruby
# app/policies/feature_policy.rb
class FeaturePolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def dark_mode?
    user&.preferences&.dark_mode_enabled?
  end

  def beta_features?
    user&.beta_tester?
  end

  def advanced_analytics?
    user&.admin? || user&.premium?
  end
end

# In view:
<% if policy(:feature).dark_mode? %>
  <%= stylesheet_link_tag "dark_mode" %>
<% end %>
```

### Step 5: Use in Views

```erb
<!-- app/views/shared/_navigation.html.erb -->
<nav>
  <%= link_to "Home", root_path %>
  <%= link_to "Blogs", blogs_path %>

  <% if user_signed_in? %>
    <%= link_to "My Posts", user_profile_path %>

    <!-- Show admin link only for admins -->
    <% if policy(:admin).manage_users? %>
      <%= link_to "Admin", admin_dashboard_path, class: 'admin-link' %>
    <% end %>
  <% end %>
</nav>
```

---

## Topic 7: Displaying Elements Conditionally in Views

### What Does policy() Do in Views?

The `policy()` helper lets you check permissions directly in your ERB templates. It returns the policy instance for the given record or symbol.

```erb
<!-- For a record: call policy method on that record -->
<%= policy(@blog).edit? %>
  ↓ Returns true/false
  ↓ Can use in if/unless blocks

<!-- For a headless policy: use symbol -->
<%= policy(:admin).dashboard? %>
  ↓ Returns true/false
  ↓ Can use in if/unless blocks
```

### Why Check Permissions in Views?

1. **User experience** - Don't show buttons users can't use
2. **Clean UI** - Hide UI elements they have no access to
3. **Reduce confusion** - User sees only relevant options
4. **Safety net** - Even if controller check fails, UI doesn't show it

**Important:** View checks are NOT security!

```ruby
# ⚠️ CRITICAL: Never rely on view checks for security!
# Someone could:
# 1. Inspect element and make requests directly
# 2. Disable JavaScript and submit forms
# 3. Use curl/postman to bypass your UI

# ✅ ALWAYS protect in controller/policy
# View checks are just UX improvements
```

### Step 1: Use policy() Helper in Views

```erb
<!-- Check single permission -->
<% if policy(@blog).edit? %>
  <%= link_to "Edit", edit_blog_path(@blog) %>
<% end %>

<!-- Check multiple permissions (OR condition) -->
<% if policy(@blog).edit? || policy(@blog).destroy? %>
  <div class="action-buttons">
    <% if policy(@blog).edit? %>
      <%= link_to "Edit", edit_blog_path(@blog) %>
    <% end %>

    <% if policy(@blog).destroy? %>
      <%= link_to "Delete", blog_path(@blog), method: :delete %>
    <% end %>
  </div>
<% end %>

<!-- Check multiple permissions (AND condition) -->
<% if policy(@blog).edit? && policy(@blog).publish? %>
  <!-- Only show if user can both edit AND publish -->
  <%= link_to "Edit & Publish", edit_blog_path(@blog) %>
<% end %>
```

**Behind the scenes:**
```
<%= policy(@blog).edit? %>
   ↓
Pundit calls: BlogPolicy.new(current_user, @blog).edit?
   ↓
Returns: true or false based on policy logic
   ↓
Used in if/unless/&&/|| conditions
```

### Step 2: Blog Index - Show Action Buttons Conditionally

Real-world example showing how different users see different options:

```erb
<!-- app/views/blogs/index.html.erb -->
<div class="blogs-list">
  <% @blogs.each do |blog| %>
    <div class="blog-card">
      <h2><%= link_to blog.title, blog_path(blog) %></h2>

      <!-- Show status badge (Draft/Published) if user can see it -->
      <!-- Custom policy method checks if user should see publication status -->
      <% if policy(blog).view_published_attribute? %>
        <span class="status <%= blog.published? ? 'published' : 'draft' %>">
          <%= blog.published? ? 'Published' : 'Draft' %>
        </span>
      <% end %>

      <p><%= truncate(blog.description, length: 150) %></p>

      <div class="actions">
        <!-- View button always available (all authorized users can view) -->
        <%= link_to "View", blog_path(blog), class: 'btn-primary' %>

        <!-- Edit button - show only to blog owner or admin -->
        <% if policy(blog).edit? %>
          <%= link_to "Edit", edit_blog_path(blog), class: 'btn-warning' %>
        <% end %>

        <!-- Delete button - show only to blog owner or admin -->
        <% if policy(blog).destroy? %>
          <%= link_to "Delete", blog_path(blog),
              method: :delete,
              data: { confirm: "Are you sure?" },
              class: 'btn-danger' %>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

**User experiences:**

```
Anonymous/Guest visiting /blogs
├── Sees published blogs only
├── Only has "View" button
└── No Edit/Delete buttons shown

Reader signed in visiting /blogs
├── Sees published blogs only
├── Only has "View" button
└── No Edit/Delete buttons shown

Author (blog owner) visiting /blogs
├── Sees published blogs + their own drafts
├── Own blogs show: View, Edit, Delete buttons
├── Others' blogs show: View button only
└── Draft status visible on their own blogs

Admin visiting /blogs
├── Sees all blogs (published + drafts)
├── Every blog shows: View, Edit, Delete buttons
├── Can see which are drafts
└── Can edit/delete any blog
```

### Step 3: User Profile - Separated Published and Drafts

```erb
<!-- app/views/users/profile.html.erb -->
<div class="user-profile">
  <h1><%= @user.username %></h1>

  <!-- Published Posts Section -->
  <div class="published-section">
    <h2>Published Posts (<%= @published_blogs.count %>)</h2>

    <% if @published_blogs.any? %>
      <% @published_blogs.each do |blog| %>
        <div class="blog-item">
          <h3><%= link_to blog.title, blog_path(blog) %></h3>
          <span class="status published">Published</span>

          <!-- Edit button only if authorized -->
          <% if policy(blog).edit? %>
            <%= link_to "Edit", edit_blog_path(blog), class: 'btn-small' %>
          <% end %>
        </div>
      <% end %>
    <% else %>
      <p>No published posts yet.</p>
    <% end %>
  </div>

  <!-- Draft Posts Section -->
  <div class="draft-section">
    <h2>Draft Posts (<%= @draft_blogs.count %>)</h2>

    <% if @draft_blogs.any? %>
      <% @draft_blogs.each do |blog| %>
        <div class="blog-item">
          <h3><%= link_to blog.title, blog_path(blog) %></h3>
          <span class="status draft">Draft</span>

          <!-- Edit and Delete buttons -->
          <% if policy(blog).edit? %>
            <%= link_to "Edit", edit_blog_path(blog), class: 'btn-small' %>
          <% end %>

          <% if policy(blog).destroy? %>
            <%= link_to "Delete", blog_path(blog),
                method: :delete,
                data: { confirm: "Sure?" },
                class: 'btn-small btn-danger' %>
          <% end %>
        </div>
      <% end %>
    <% else %>
      <p>No drafts. <%= link_to "Create one", new_blog_path %></p>
    <% end %>
  </div>
</div>
```

### Step 4: Admin Panel - User Management

```erb
<!-- app/views/admin/users/index.html.erb -->
<table class="users-table">
  <thead>
    <tr>
      <th>Username</th>
      <th>Email</th>
      <th>Role</th>
      <th>Status</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @users.each do |user| %>
      <tr>
        <td><%= user.username %></td>
        <td><%= user.email %></td>
        <td>
          <span class="role-badge <%= user.role %>">
            <%= user.role.titleize %>
          </span>
        </td>
        <td>
          <span class="status <%= user.active? ? 'active' : 'inactive' %>">
            <%= user.active? ? 'Active' : 'Inactive' %>
          </span>
        </td>
        <td class="actions">
          <!-- Edit button -->
          <% if policy(user).edit? %>
            <%= link_to "Edit", edit_admin_user_path(user), class: 'btn-small' %>
          <% end %>

          <!-- Deactivate button for active users -->
          <% if user.active? && policy(user).deactivate? %>
            <%= link_to "Deactivate",
                deactivate_admin_user_path(user),
                method: :patch,
                data: { confirm: "Sure?" },
                class: 'btn-small btn-danger' %>
          <% end %>

          <!-- Activate button for inactive users -->
          <% if !user.active? && policy(user).activate? %>
            <%= link_to "Activate",
                activate_admin_user_path(user),
                method: :patch,
                class: 'btn-small btn-success' %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

### Step 5: Navigation Bar - Admin Link Visibility

```erb
<!-- app/views/shared/_navigation.html.erb -->
<nav class="navbar">
  <div class="nav-brand">
    <%= link_to "BlogApp", root_path %>
  </div>

  <ul class="nav-links">
    <li><%= link_to "Home", root_path %></li>
    <li><%= link_to "Blogs", blogs_path %></li>

    <% if user_signed_in? %>
      <li><%= link_to "My Posts", user_profile_path %></li>

      <!-- Admin link visible only to admins -->
      <% if admin? %>
        <li>
          <%= link_to "Admin", admin_users_path,
              class: 'admin-link',
              style: 'background: #dc3545; color: white; padding: 6px 12px; border-radius: 4px;' %>
        </li>
      <% end %>
    <% end %>
  </ul>

  <div class="nav-auth">
    <% if user_signed_in? %>
      <span class="user-email"><%= current_user.email %></span>
      <%= link_to "My Posts", user_profile_path %>
      <%= link_to "Settings", edit_user_registration_path %>
      <%= link_to "Logout", destroy_user_session_path, method: :delete %>
    <% else %>
      <%= link_to "Login", new_user_session_path %>
      <%= link_to "Sign Up", new_user_registration_path %>
    <% end %>
  </div>
</nav>
```

### Step 6: Helper Methods for Complex Logic

For complex permission checks, create helper methods to keep views clean:

```ruby
# app/helpers/blogs_helper.rb
module BlogsHelper
  # Helpers make views more readable and maintainable
  def show_edit_button?(blog)
    policy(blog).edit?
  end

  def show_delete_button?(blog)
    policy(blog).destroy?
  end

  def show_publish_button?(blog)
    policy(blog).publish?
  end

  def show_status_badge?(blog)
    policy(blog).view_published_attribute?
  end

  # More complex logic example
  def show_admin_actions?(blog)
    policy(blog).edit? && policy(blog).destroy?
  end

  # Helper for role-based display
  def can_manage_blog?(blog)
    policy(blog).edit? || policy(blog).destroy?
  end
end
```

**Why use helpers?**

```erb
<!-- ❌ View becomes cluttered with policy checks -->
<% if policy(@blog).edit? || policy(@blog).destroy? %>
  <% if policy(@blog).view_published_attribute? %>
    <% if policy(@blog).edit? %>
      <!-- nested ifs are hard to read -->
    <% end %>
  <% end %>
<% end %>

<!-- ✅ Helpers make it readable -->
<% if can_manage_blog?(@blog) %>
  <% if show_status_badge?(@blog) %>
    <% if show_edit_button?(@blog) %>
      <!-- Much clearer intent -->
    <% end %>
  <% end %>
<% end %>
```

**Using helpers in views:**

```erb
<!-- app/views/blogs/show.html.erb -->
<div class="blog-actions">
  <!-- Use helpers instead of inline policy checks -->
  <% if show_edit_button?(@blog) %>
    <%= link_to "Edit", edit_blog_path(@blog), class: 'btn btn-primary' %>
  <% end %>

  <% if show_delete_button?(@blog) %>
    <%= link_to "Delete", blog_path(@blog),
        method: :delete,
        data: { confirm: "Sure?" },
        class: 'btn btn-danger' %>
  <% end %>

  <% if show_publish_button?(@blog) %>
    <%= link_to "Publish", publish_blog_path(@blog),
        method: :post,
        class: 'btn btn-success' %>
  <% end %>
</div>
```

**Benefits of helper methods:**
- **Readability** - View code is more semantic
- **Reusability** - Use same helper in multiple views
- **Maintainability** - Change logic once, affects all uses
- **Testability** - Easier to test helpers than inline logic
- **Consistency** - Same checks everywhere

---

## Topic 8: Using policy(@post).update? in Views

### Understanding policy() and Method Names

The `policy()` helper returns the policy instance, so you can call any method on it. The method names typically follow Rails conventions:

```erb
<!-- Standard CRUD methods (from ApplicationPolicy) -->
<% if policy(@blog).index? %>    <!-- Can list blogs? -->
<% if policy(@blog).show? %>     <!-- Can view this blog? -->
<% if policy(@blog).create? %>   <!-- Can create blog? -->
<% if policy(@blog).new? %>      <!-- Can see create form? -->
<% if policy(@blog).update? %>   <!-- Can edit this blog? -->
<% if policy(@blog).edit? %>     <!-- Can see edit form? -->
<% if policy(@blog).destroy? %>  <!-- Can delete this blog? -->

<!-- Custom methods you define in policy -->
<% if policy(@blog).publish? %>        <!-- Custom method -->
<% if policy(@blog).own_blog? %>       <!-- Custom method -->
<% if policy(@blog).share? %>          <!-- Custom method -->
<% if policy(@blog).archive? %>        <!-- Custom method -->
```

### Step 1: Direct Policy Method Calls

```erb
<!-- Check if user can update -->
<% if policy(@blog).update? %>
  <!-- Show editable content or edit button -->
  <%= link_to "Edit This Blog", edit_blog_path(@blog) %>
<% end %>

<!-- Check if user can delete -->
<% if policy(@blog).destroy? %>
  <%= link_to "Delete", blog_path(@blog), method: :delete %>
<% end %>

<!-- Check custom methods defined in policy -->
<% if policy(@blog).publish? %>
  <%= link_to "Publish", publish_blog_path(@blog), method: :post %>
<% end %>

<!-- Check attribute-level permissions -->
<% if policy(@blog).view_published_attribute? %>
  <span class="status">
    <%= @blog.published? ? 'Published' : 'Draft' %>
  </span>
<% end %>

<!-- Check custom helper method -->
<% if policy(@blog).can_be_archived? %>
  <%= link_to "Archive", archive_blog_path(@blog), method: :post %>
<% end %>
```

**Policy methods are checked BEFORE rendering:**

```
View loads: <% if policy(@blog).edit? %>
  ↓
Pundit calls: BlogPolicy.new(current_user, @blog).edit?
  ↓
Policy checks: user.admin? || record.user == user
  ↓
Returns: true or false
  ↓
Template either shows or hides the link
```

### Step 2: Combine Multiple Policy Checks

You can combine policy checks with logical operators (AND, OR) to create more complex authorization UI logic:

```erb
<!-- OR condition: Show if user can EITHER edit OR delete -->
<% if policy(@blog).update? || policy(@blog).destroy? %>
  <div class="admin-actions">
    <% if policy(@blog).update? %>
      <%= link_to "Edit", edit_blog_path(@blog), class: 'btn btn-warning' %>
    <% end %>

    <% if policy(@blog).destroy? %>
      <%= link_to "Delete", blog_path(@blog),
          method: :delete,
          data: { confirm: "Sure?" },
          class: 'btn btn-danger' %>
    <% end %>
  </div>
<% end %>

<!-- AND condition: Show if user can BOTH edit AND publish -->
<% if policy(@blog).update? && policy(@blog).publish? %>
  <div class="advanced-actions">
    <%= link_to "Edit & Publish", edit_publish_blog_path(@blog) %>
  </div>
<% end %>

<!-- Complex condition: Show advanced options to owners/admins -->
<% if policy(@blog).update? %>
  <div class="editor-options">
    <% if policy(@blog).destroy? %>
      <%= link_to "Delete", blog_path(@blog), method: :delete %>
    <% end %>

    <% if policy(@blog).publish? %>
      <%= link_to "Publish", publish_blog_path(@blog), method: :post %>
    <% end %>

    <% if policy(@blog).archive? %>
      <%= link_to "Archive", archive_blog_path(@blog), method: :post %>
    <% end %>
  </div>
<% end %>
```

**Real-world example: Blog card with conditional actions**

```erb
<div class="blog-card">
  <h3><%= @blog.title %></h3>

  <!-- Everyone can view published blogs -->
  <%= link_to "View", blog_path(@blog) %>

  <!-- Only show admin/edit section if user can do anything -->
  <% if policy(@blog).update? || policy(@blog).destroy? %>
    <div class="card-actions">
      <!-- Edit only if allowed -->
      <% if policy(@blog).update? %>
        <%= link_to "✏️", edit_blog_path(@blog), title: 'Edit' %>
      <% end %>

      <!-- Delete only if allowed -->
      <% if policy(@blog).destroy? %>
        <%= link_to "🗑️", blog_path(@blog), method: :delete, title: 'Delete' %>
      <% end %>

      <!-- More actions if owner -->
      <% if policy(@blog).own_blog? %>
        <div class="owner-actions">
          <% if policy(@blog).publish? %>
            <%= link_to "Publish", publish_blog_path(@blog), method: :post %>
          <% end %>

          <% if policy(@blog).share? %>
            <%= link_to "Share", share_blog_path(@blog) %>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

### Step 3: Real Example - Blog Show Page

A complete blog show page demonstrating all types of policy checks:

```erb
<!-- app/views/blogs/show.html.erb -->
<div class="blog-container">
  <div class="blog-header">
    <h1><%= @blog.title %></h1>

    <!-- Status badge - only show to authorized viewers -->
    <!-- Only blog owner and admin should see Draft status -->
    <% if policy(@blog).view_published_attribute? %>
      <span class="badge <%= @blog.published? ? 'badge-success' : 'badge-warning' %>">
        <%= @blog.published? ? 'Published' : 'Draft' %>
      </span>
    <% end %>
  </div>

  <div class="blog-content">
    <p><%= @blog.description %></p>
  </div>

  <!-- Metadata about the blog -->
  <div class="blog-meta">
    <p>
      By <strong><%= @blog.user.username %></strong>
      on <%= @blog.created_at.strftime("%B %d, %Y") %>
    </p>
  </div>

  <!-- Action buttons - visibility based on authorization -->
  <div class="blog-actions">
    <!-- Navigation: Back button - always available -->
    <%= link_to "Back to Blogs", blogs_path, class: 'btn btn-secondary' %>

    <!-- Only show action buttons if user can do something -->
    <% if policy(@blog).update? || policy(@blog).destroy? %>
      <div class="editor-actions">

        <!-- Edit button - only if user can update -->
        <% if policy(@blog).update? %>
          <%= link_to "Edit", edit_blog_path(@blog),
              class: 'btn btn-primary',
              title: 'Edit this blog post' %>
        <% end %>

        <!-- Delete button - only if user can destroy -->
        <% if policy(@blog).destroy? %>
          <%= link_to "Delete", blog_path(@blog),
              method: :delete,
              data: { confirm: "Are you sure? This cannot be undone." },
              class: 'btn btn-danger',
              title: 'Permanently delete this blog post' %>
        <% end %>

      </div>
    <% end %>

    <!-- Custom actions: Publish/Unpublish -->
    <!-- These check custom policy methods -->
    <% if policy(@blog).update? %>
      <div class="publish-actions">
        <% if !@blog.published? && policy(@blog).publish? %>
          <%= link_to "Publish Post", publish_blog_path(@blog),
              method: :post,
              class: 'btn btn-success' %>
        <% elsif @blog.published? && policy(@blog).unpublish? %>
          <%= link_to "Unpublish Post", unpublish_blog_path(@blog),
              method: :post,
              class: 'btn btn-warning' %>
        <% end %>
      </div>
    <% end %>

  </div>
</div>
```

**Authorization flow for different users:**

```
Anonymous visits /blogs/1 (published blog)
├── policy(@blog).view_published_attribute? → false
│   └── Status badge NOT shown
├── policy(@blog).update? → false
│   └── Edit button NOT shown
├── policy(@blog).destroy? → false
│   └── Delete button NOT shown
└── Result: Only sees content, no action buttons

Reader visits /blogs/1 (published blog)
├── policy(@blog).view_published_attribute? → false
│   └── Status badge NOT shown
├── policy(@blog).update? → false
│   └── Edit button NOT shown
├── policy(@blog).destroy? → false
│   └── Delete button NOT shown
└── Result: Same as anonymous - can only read

Author visits their own blog
├── policy(@blog).view_published_attribute? → true
│   └── Status badge SHOWN (can see Draft/Published)
├── policy(@blog).update? → true
│   └── Edit button SHOWN
├── policy(@blog).destroy? → true
│   └── Delete button SHOWN
├── policy(@blog).publish? → true
│   └── Publish button SHOWN (if draft)
└── Result: Full control over their own post

Admin visits any blog
├── policy(@blog).view_published_attribute? → true
│   └── Status badge SHOWN
├── policy(@blog).update? → true
│   └── Edit button SHOWN
├── policy(@blog).destroy? → true
│   └── Delete button SHOWN
├── policy(@blog).publish? → true
│   └── Publish button SHOWN
└── Result: Full control over any post
```

### Step 4: Inline Conditions & Advanced Patterns

Use ternary operators and inline conditions for simple permission checks:

```erb
<!-- Ternary operator: Show different content based on permission -->
<div class="blog-title">
  <%= policy(@blog).update? ?
      link_to('Edit', edit_blog_path(@blog)) :
      content_tag(:span, 'Readonly') %>
</div>

<!-- Toggle between view and edit based on policy -->
<div class="blog-title">
  <% if policy(@blog).update? %>
    <!-- User can edit - show editable field -->
    <%= form_with model: @blog, local: true do |f| %>
      <%= f.text_field :title, class: 'editable-title' %>
    <% end %>
  <% else %>
    <!-- User cannot edit - show as text -->
    <h1><%= @blog.title %></h1>
  <% end %>
</div>

<!-- Show different links based on permission -->
<div class="action-links">
  <% if policy(@user).update? %>
    <%= link_to 'Edit Profile', edit_user_path(@user) %>
  <% elsif policy(@user).show? %>
    <%= link_to 'View Profile', user_path(@user) %>
  <% else %>
    <span>Profile not available</span>
  <% end %>
</div>

<!-- Conditional CSS classes based on permission -->
<div class="blog-content <%= 'editable' if policy(@blog).update? %>">
  <h1><%= @blog.title %></h1>
  <p><%= @blog.description %></p>
</div>

<!-- Chain policy checks with conditions -->
<% if policy(@blog).update? && !@blog.published? %>
  <!-- Show publish button only if user can edit AND post is unpublished -->
  <%= link_to "Publish", publish_blog_path(@blog), method: :post %>
<% end %>
```

**Pattern: Show admin tools only if user can do something**

```erb
<!-- Use || (OR) to show if ANY action is available -->
<% if policy(@user).update? || policy(@user).deactivate? || policy(@user).activate? %>
  <div class="admin-tools">
    <% if policy(@user).update? %>
      <%= link_to 'Edit', edit_user_path(@user) %>
    <% end %>

    <% if policy(@user).deactivate? && @user.active? %>
      <%= link_to 'Deactivate', deactivate_user_path(@user), method: :patch %>
    <% end %>

    <% if policy(@user).activate? && !@user.active? %>
      <%= link_to 'Activate', activate_user_path(@user), method: :patch %>
    <% end %>
  </div>
<% end %>
```

**Pattern: Progressively disclosure of features**

```erb
<!-- Basic level: Can user see this at all? -->
<% if policy(:feature).dark_mode? %>
  <div class="theme-controls">
    <!-- Medium level: Can user enable/disable? -->
    <% if policy(:feature).configure_theme? %>
      <%= link_to 'Configure Theme', theme_settings_path %>
    <% else %>
      <!-- Read-only view -->
      <span>Dark mode: <%= @user.dark_mode_enabled? ? 'On' : 'Off' %></span>
    <% end %>
  </div>
<% end %>
```

### Step 5: Conditional CSS Classes

```erb
<!-- Add CSS class if user can modify -->
<div class="blog <%= 'editable' if policy(@blog).update? %>">
  <h1><%= @blog.title %></h1>
  <p><%= @blog.description %></p>
</div>

<!-- CSS -->
<style>
  .blog.editable {
    border: 2px dashed #ffc107;
    padding: 10px;
  }

  .blog.editable:hover {
    background-color: #f9f9f9;
  }
</style>
```

### Step 6: Real Project - Admin User Show Page

```erb
<!-- app/views/admin/users/show.html.erb -->
<div class="user-details">
  <h1><%= @user.username %></h1>

  <div class="user-info">
    <p><strong>Email:</strong> <%= @user.email %></p>
    <p><strong>Role:</strong> <%= @user.role.titleize %></p>
    <p><strong>Status:</strong>
      <span class="status <%= @user.active? ? 'active' : 'inactive' %>">
        <%= @user.active? ? 'Active' : 'Inactive' %>
      </span>
    </p>
  </div>

  <!-- User's blogs -->
  <div class="user-blogs">
    <h2>User's Blogs</h2>

    <!-- Published section -->
    <h3>Published (<%= @user.blogs.published.count %>)</h3>
    <% @user.blogs.published.each do |blog| %>
      <div class="blog-item">
        <%= link_to blog.title, blog_path(blog) %>
        <span class="status published">Published</span>
      </div>
    <% end %>

    <!-- Drafts section -->
    <h3>Drafts (<%= @user.blogs.drafts.count %>)</h3>
    <% @user.blogs.drafts.each do |blog| %>
      <div class="blog-item">
        <%= link_to blog.title, blog_path(blog) %>
        <span class="status draft">Draft</span>
      </div>
    <% end %>
  </div>

  <!-- Admin actions - show based on policy -->
  <div class="admin-actions">
    <% if policy(@user).edit? %>
      <%= link_to "Edit User", edit_admin_user_path(@user), class: 'btn btn-primary' %>
    <% end %>

    <% if @user.active? && policy(@user).deactivate? %>
      <%= link_to "Deactivate", deactivate_admin_user_path(@user),
          method: :patch,
          data: { confirm: "Deactivate this user?" },
          class: 'btn btn-danger' %>
    <% end %>

    <% if !@user.active? && policy(@user).activate? %>
      <%= link_to "Activate", activate_admin_user_path(@user),
          method: :patch,
          class: 'btn btn-success' %>
    <% end %>
  </div>

  <%= link_to "Back to Users", admin_users_path, class: 'btn btn-secondary' %>
</div>
```

---

## Complete Workflow Example

### Scenario: User Creates and Publishes a Blog

**Step 1: Authorization Handler is Ready**
```ruby
# app/controllers/application_controller.rb
rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
```

**Step 2: User Navigates to Blogs Index**
```ruby
# BlogsController#index
@blogs = policy_scope(Blog)  # ← Topic 5
# Scope filters (Topic 4): Shows only authorized blogs
```

**Step 3: Policy Scope Works Silently**
```ruby
# BlogPolicy::Scope#resolve (Topic 4)
# Reader sees: [published_1, published_2]
# Author sees: [published_1, my_draft_1, published_2]
# Admin sees: [all blogs]
```

**Step 4: View Shows Conditional Buttons**
```erb
<!-- Topics 7 & 8 -->
<% if policy(blog).edit? %>
  <%= link_to "Edit", edit_blog_path(blog) %>
<% end %>
```

**Step 5: Author Creates Blog with Publish Button**
```erb
<!-- Form with two submit buttons -->
<%= form.button "Publish Post", name: "commit", value: "publish" %>
<%= form.button "Save as Draft", name: "commit", value: "draft" %>
```

**Step 6: Controller Handles Publish/Draft**
```ruby
# BlogsController#create
@blog.published = params[:commit] == 'publish'
```

**Step 7: Authorization Check**
```ruby
authorize @blog  # ← Topic 1: Error handling
# Shows custom message (Topic 2) if unauthorized
```

**Step 8: View Shows Status**
```erb
<!-- Topic 7 & 8 -->
<% if policy(@blog).view_published_attribute? %>
  <span><%= @blog.published? ? 'Published' : 'Draft' %></span>
<% end %>
```

**Step 9: Admin Can Manage**
```erb
<!-- Headless policy (Topic 6) -->
<% if policy(:admin).manage_users? %>
  <%= link_to "Admin Panel", admin_users_path %>
<% end %>
```

**Step 10: All Protected**
- Each action authorized (Topic 1)
- Custom error messages shown (Topic 2)
- Collections filtered securely (Topics 3, 4, 5)
- UI shows/hides conditionally (Topics 7, 8)
- System-wide authorization (Topic 6)

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Using Blog.all without scope
```ruby
@blogs = Blog.all  # SECURITY RISK!
```
**Fix:** Use `policy_scope(Blog)`

### ❌ Mistake 2: Converting scope to array
```ruby
scope.all.to_a  # Breaks method chaining!
```
**Fix:** Return scope directly

### ❌ Mistake 3: No authorize in controller
```ruby
@blog.destroy  # No authorization check!
```
**Fix:** Add `authorize @blog` first

### ❌ Mistake 4: Showing UI without checking
```erb
<%= link_to "Delete", blog_path(@blog) %>  <!-- Misleading! -->
```
**Fix:** Wrap in `<% if policy(@blog).destroy? %>`

### ❌ Mistake 5: Not handling nil user
```ruby
def edit?
  record.user == user  # Crashes if user is nil!
end
```
**Fix:** Use `user.present? && record.user == user`

---

## Quick Reference

| Topic | Purpose | Key Method |
|-------|---------|-----------|
| 1 | Catch unauthorized | `rescue_from Pundit::NotAuthorizedError` |
| 2 | Explain why denied | `authorization_message(action)` |
| 3 | Filter collections | `policy_scope(Model)` |
| 4 | Implement filtering | `Scope#resolve` |
| 5 | Use in controllers | `policy_scope(Model).order()` |
| 6 | Non-model auth | `authorize :namespace, :action?` |
| 7 | Show/hide UI | `<% if policy(@obj).action? %>` |
| 8 | Direct policy calls | `policy(@post).update?` |

### Topic 2 Implementation Details

**Key Pattern:**
- Policy methods define what actions are allowed (`:create?`, `:update?`, etc.)
- `authorization_message(action)` provides user-friendly feedback for each denied action
- ApplicationController extracts the action from the exception and calls the policy method
- User sees specific, actionable error messages instead of generic ones

**Exception Flow:**
```
authorize @blog
  ↓ (fails)
Pundit::NotAuthorizedError raised
  ├── exception.policy = BlogPolicy instance
  ├── exception.query = "destroy?"
  └── exception.record = @blog
  ↓
ApplicationController#user_not_authorized catches it
  ├── Extracts :destroy from "destroy?"
  ├── Calls policy.authorization_message(:destroy)
  └── Sets flash[:alert] with specific message
  ↓
Redirects with contextual error message

---

## Next Steps

1. **Implement** - Add these 8 topics to your app
2. **Test** - Write tests for each authorization path
3. **Refine** - Add more custom messages and conditions
4. **Monitor** - Log unauthorized attempts
5. **Scale** - Handle complex multi-role scenarios

---

**References:**
- See `PUNDIT.md` for foundational concepts
- See `PUNDIT_GUIDE.md` for additional patterns
- [Pundit GitHub](https://github.com/varvet/pundit)

---

## Implementation Status

✅ **Fully Implemented in This Project**

The following Topic 2 features are complete:

- ✅ ApplicationController catches `Pundit::NotAuthorizedError`
- ✅ Extracts action name from exception.query
- ✅ BlogPolicy has action-specific authorization messages
- ✅ UserPolicy has detailed action-specific messages
- ✅ AdminPolicy (headless) has admin-specific messages
- ✅ All policies respond to `authorization_message(action)`
- ✅ Error handler provides contextual feedback
- ✅ Flash messages guide users on authorization failures

**Project Files:**
- `app/controllers/application_controller.rb` - Error handler
- `app/policies/blog_policy.rb` - Blog-specific messages
- `app/policies/user_policy.rb` - User management messages
- `app/policies/admin_policy.rb` - Admin section messages

---

**Last Updated:** January 2026
**Status:** Tutorial & Hands-On Guide with Completed Implementation
**Difficulty:** Beginner to Intermediate
