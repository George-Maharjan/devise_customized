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

### Step 3: Test the Error Handler

```ruby
# test/controllers/blogs_controller_test.rb
test "reader cannot delete blog" do
  reader = users(:reader)
  blog = blogs(:one)
  sign_in reader

  delete blog_path(blog)

  # Check that error handler worked
  assert_redirected_to root_path
  assert_includes flash[:alert], "not authorized"

  # Blog still exists (wasn't deleted)
  assert Blog.exists?(blog.id)
end
```

### Step 4: Customize Error Responses

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

```ruby
# app/policies/blog_policy.rb
class BlogPolicy < ApplicationPolicy
  def authorization_message
    # Check different conditions and return appropriate message
    if !user.present?
      "You must be logged in to perform this action"
    elsif record.published?
      "Cannot edit published blogs"
    elsif !own_blog? && !user&.admin?
      "Only the blog owner can edit this"
    else
      "You are not authorized"
    end
  end

  private

  def own_blog?
    record.user == user
  end
end
```

### Step 2: Update ApplicationController to Use Custom Messages

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    # Try to get custom message from policy
    policy_obj = exception.policy
    error_message = if policy_obj.respond_to?(:authorization_message)
                      policy_obj.authorization_message
                    else
                      "You are not authorized"
                    end

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_to request.referrer || root_path
      end

      format.json do
        render json: { error: error_message }, status: :forbidden
      end
    end
  end
end
```

### Step 3: Test Different Messages

```ruby
# test/policies/blog_policy_test.rb
test "message for anonymous user" do
  policy = BlogPolicy.new(nil, blogs(:one))
  assert_includes policy.authorization_message, "logged in"
end

test "message for non-owner trying to edit" do
  reader = users(:reader)
  blog = blogs(:draft_by_author)

  policy = BlogPolicy.new(reader, blog)
  assert_includes policy.authorization_message, "blog owner"
end

test "message for trying to edit published blog" do
  author = blogs(:published).user
  policy = BlogPolicy.new(author, blogs(:published))
  assert_includes policy.authorization_message, "published"
end
```

### Step 4: Real Project Examples

```ruby
# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  def authorization_message
    if !user&.admin?
      "Only administrators can manage users"
    elsif record.id == user.id
      "Admins cannot modify themselves"
    else
      "You are not authorized"
    end
  end
end

# app/policies/admin_policy.rb
class AdminPolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def authorization_message
    "Only administrators can access this section"
  end
end
```

### User Experience Improvement

**Before:**
```
User tries to edit another's draft
↓
"You are not authorized"
↓
User is confused - why not?
```

**After:**
```
User tries to edit another's draft
↓
"Only the blog owner can edit this"
↓
User understands immediately
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

### Step 1: Understand Scope Purpose

A scope automatically filters collections based on what the current user can see.

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

### Step 4: Test Scopes

```ruby
# test/policies/blog_policy_test.rb
class BlogPolicyScopeTest < ActiveSupport::TestCase
  test "reader sees only published" do
    reader = users(:reader)
    published = blogs(:published)
    draft = blogs(:draft)

    scope = BlogPolicy::Scope.new(reader, Blog).resolve

    assert scope.include?(published)
    assert_not scope.include?(draft)
  end

  test "author sees published and own drafts" do
    author = users(:author)
    my_draft = blogs(:my_draft)
    others_draft = blogs(:others_draft)
    published = blogs(:published)

    scope = BlogPolicy::Scope.new(author, Blog).resolve

    assert scope.include?(my_draft)
    assert_not scope.include?(others_draft)
    assert scope.include?(published)
  end

  test "admin sees all blogs" do
    admin = users(:admin)
    scope = BlogPolicy::Scope.new(admin, Blog).resolve

    assert_equal Blog.count, scope.count
  end
end
```

---

## Topic 4: Scope Class Implementation

### The Scope Class Structure

Every policy can have an inner `Scope` class that filters collections:

```ruby
class BlogPolicy < ApplicationPolicy
  # Regular authorization methods
  def update?
    own_blog? || user&.admin?
  end

  # Scope class for filtering collections
  class Scope < ApplicationPolicy::Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # Must return ActiveRecord scope (not array!)
      raise NotImplementedError
    end
  end
end
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

```ruby
class BlogPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Different filtering based on user role
      case user
      when nil
        # Guests see only published
        scope.where(published: true)

      when ->(u) { u.reader? }
        # Readers see only published
        scope.where(published: true)

      when ->(u) { u.author? }
        # Authors see published + their own drafts
        scope.where("published = true OR user_id = ?", user.id)

      when ->(u) { u.admin? }
        # Admins see everything
        scope.all

      else
        scope.where(published: true)
      end
    end
  end
end
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

### Step 6: Test Complex Scope

```ruby
test "moderator sees published and flagged" do
  moderator = users(:moderator)
  published = blogs(:published)
  flagged = blogs(:flagged_for_review)
  draft = blogs(:draft)

  scope = BlogPolicy::Scope.new(moderator, Blog).resolve

  assert scope.include?(published)
  assert scope.include?(flagged)
  assert_not scope.include?(draft)
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

### Step 6: Test in Controller

```ruby
# test/controllers/blogs_controller_test.rb
test "reader sees only published blogs" do
  reader = users(:reader)
  published = blogs(:published)
  draft = blogs(:draft)

  sign_in reader
  get blogs_path

  assert_includes assigns(:blogs), published
  assert_not_includes assigns(:blogs), draft
end

test "author sees published and own drafts" do
  author = users(:author)
  my_draft = blogs(:my_draft)
  others_draft = blogs(:others_draft)

  sign_in author
  get blogs_path

  assert_includes assigns(:blogs), my_draft
  assert_not_includes assigns(:blogs), others_draft
end
```

---

## Topic 6: Headless Policies (Policies Without Model)

### What Are Headless Policies?

Policies for actions that don't belong to a specific model:
- Admin dashboards
- Settings pages
- Feature toggles
- System-wide actions

### Step 1: Create a Headless Policy

```ruby
# app/policies/admin_policy.rb
class AdminPolicy < ApplicationPolicy
  # Override initialize - no record parameter
  def initialize(user)
    @user = user
    @record = nil  # No specific record
  end

  # Authorization methods
  def dashboard?
    user&.admin?
  end

  def manage_users?
    user&.admin?
  end

  def view_audit_logs?
    user&.admin?
  end

  def view_settings?
    user&.admin? || user&.moderator?
  end

  def authorization_message
    "Only administrators can access this section"
  end
end
```

### Step 2: Use in Controller

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
    # Pass symbol as record to headless policy
    authorize :admin, :dashboard?
  end
end
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

### Step 5: Test Headless Policies

```ruby
# test/policies/admin_policy_test.rb
test "admin can access dashboard" do
  admin = users(:admin)
  policy = AdminPolicy.new(admin)
  assert policy.dashboard?
end

test "reader cannot access dashboard" do
  reader = users(:reader)
  policy = AdminPolicy.new(reader)
  assert_not policy.dashboard?
end

test "authorization message" do
  policy = AdminPolicy.new(nil)
  assert_includes policy.authorization_message, "administrator"
end
```

### Step 6: Use in Views

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

### Step 1: Use policy() Helper in Views

```erb
<!-- Check single permission -->
<% if policy(@blog).edit? %>
  <%= link_to "Edit", edit_blog_path(@blog) %>
<% end %>

<!-- Check multiple permissions -->
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
```

### Step 2: Blog Index - Show Action Buttons Conditionally

```erb
<!-- app/views/blogs/index.html.erb -->
<div class="blogs-list">
  <% @blogs.each do |blog| %>
    <div class="blog-card">
      <h2><%= link_to blog.title, blog_path(blog) %></h2>

      <!-- Show status badge if allowed -->
      <% if policy(blog).view_published_attribute? %>
        <span class="status <%= blog.published? ? 'published' : 'draft' %>">
          <%= blog.published? ? 'Published' : 'Draft' %>
        </span>
      <% end %>

      <p><%= truncate(blog.description, length: 150) %></p>

      <div class="actions">
        <!-- View button always available -->
        <%= link_to "View", blog_path(blog), class: 'btn-primary' %>

        <!-- Edit button - show only if authorized -->
        <% if policy(blog).edit? %>
          <%= link_to "Edit", edit_blog_path(blog), class: 'btn-warning' %>
        <% end %>

        <!-- Delete button - show only if authorized -->
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

```ruby
# app/helpers/blogs_helper.rb
module BlogsHelper
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
end
```

Use in views:

```erb
<% if show_edit_button?(@blog) %>
  <%= link_to "Edit", edit_blog_path(@blog) %>
<% end %>

<% if show_delete_button?(@blog) %>
  <%= link_to "Delete", blog_path(@blog), method: :delete %>
<% end %>

<% if show_status_badge?(@blog) %>
  <span class="status"><%= @blog.published? ? 'Published' : 'Draft' %></span>
<% end %>
```

---

## Topic 8: Using policy(@post).update? in Views

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

<!-- Check custom methods -->
<% if policy(@blog).publish? %>
  <%= link_to "Publish", publish_blog_path(@blog), method: :post %>
<% end %>
```

### Step 2: Combine Multiple Policy Checks

```erb
<!-- Show action buttons only if user can do something -->
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
```

### Step 3: Real Example - Blog Show Page

```erb
<!-- app/views/blogs/show.html.erb -->
<div class="blog-container">
  <h1><%= @blog.title %></h1>

  <!-- Status badge -->
  <% if policy(@blog).view_published_attribute? %>
    <span class="badge <%= @blog.published? ? 'badge-success' : 'badge-warning' %>">
      <%= @blog.published? ? 'Published' : 'Draft' %>
    </span>
  <% end %>

  <p class="blog-content">
    <%= @blog.description %>
  </p>

  <!-- User info -->
  <div class="blog-meta">
    By <strong><%= @blog.user.username %></strong>
    on <%= @blog.created_at.strftime("%B %d, %Y") %>
  </div>

  <!-- Action buttons - show based on authorization -->
  <div class="blog-actions">
    <!-- View button always available -->
    <%= link_to "Back to Blogs", blogs_path, class: 'btn btn-secondary' %>

    <!-- Edit button - only if policy allows -->
    <% if policy(@blog).update? %>
      <%= link_to "Edit", edit_blog_path(@blog), class: 'btn btn-primary' %>
    <% end %>

    <!-- Delete button - only if policy allows -->
    <% if policy(@blog).destroy? %>
      <%= link_to "Delete", blog_path(@blog),
          method: :delete,
          data: { confirm: "Delete this blog?" },
          class: 'btn btn-danger' %>
    <% end %>

    <!-- Publish button - only if policy allows -->
    <% if policy(@blog).publish? %>
      <%= link_to "Publish", publish_blog_path(@blog),
          method: :post,
          class: 'btn btn-success' %>
    <% end %>
  </div>
</div>
```

### Step 4: Inline Conditions

```erb
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

### Step 6: Test Conditional Rendering

```ruby
# test/views/blogs/show_test.rb
test "edit button visible to blog owner" do
  render
  blog = blogs(:one)
  owner = blog.user

  sign_in owner

  assert_select "a", text: "Edit"
end

test "edit button hidden from unauthorized users" do
  render
  blog = blogs(:one)
  reader = users(:reader)

  sign_in reader

  assert_select "a", text: "Edit", count: 0
end

test "delete button visible to admin" do
  render
  blog = blogs(:one)
  admin = users(:admin)

  sign_in admin

  assert_select "a", text: "Delete"
end

test "delete button hidden from readers" do
  render
  blog = blogs(:one)
  reader = users(:reader)

  sign_in reader

  assert_select "a", text: "Delete", count: 0
end
```

### Step 7: Real Project - Admin User Show Page

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

## Testing Checklist

For each authorization feature:

- [ ] Test policy returns `true` for authorized users
- [ ] Test policy returns `false` for unauthorized users
- [ ] Test scope includes only authorized records
- [ ] Test scope excludes unauthorized records
- [ ] Test controller raises error for unauthorized access
- [ ] Test error handler shows custom message
- [ ] Test error handler redirects properly
- [ ] Test view shows button for authorized user
- [ ] Test view hides button for unauthorized user
- [ ] Test headless policy works
- [ ] Test multiple roles get different data
- [ ] Test nil user (not logged in) case

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
| 1 | Catch unauthorized | `rescue_from` |
| 2 | Explain why denied | `authorization_message` |
| 3 | Filter collections | `policy_scope(Model)` |
| 4 | Implement filtering | `Scope#resolve` |
| 5 | Use in controllers | `policy_scope(Model).order()` |
| 6 | Non-model auth | `authorize :namespace, :action?` |
| 7 | Show/hide UI | `<% if policy(@obj).action? %>` |
| 8 | Direct policy calls | `policy(@post).update?` |

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

**Last Updated:** January 2026
**Status:** Tutorial & Hands-On Guide
**Difficulty:** Beginner to Intermediate
