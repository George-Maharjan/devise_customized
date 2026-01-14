# Pundit Authorization Guide - Complete Educational Edition

## Table of Contents
1. [Why Authorization Matters](#why-authorization-matters)
2. [Conceptual Foundations](#conceptual-foundations)
3. [Authentication vs Authorization](#authentication-vs-authorization)
4. [How Pundit Works](#how-pundit-works)
5. [Implementation Guide](#implementation-guide)
6. [Design Decisions Explained](#design-decisions-explained)
7. [Security Considerations](#security-considerations)
8. [Testing Strategy](#testing-strategy)
9. [Common Pitfalls](#common-pitfalls)
10. [Best Practices](#best-practices)

---

## Why Authorization Matters

### The Security Risk

Imagine you're building a blogging platform. Without proper authorization:

```ruby
# DANGEROUS - No authorization check!
def update
  @blog = Blog.find(params[:id])
  @blog.update(blog_params)  # Any logged-in user can edit ANY blog!
  redirect_to @blog
end
```

A user could craft a URL like `/blogs/999/edit` and modify someone else's content:
- Delete important information
- Change the author's name
- Add false information
- Steal private thoughts

### Real-World Impact

**Data Breaches**: 42% of data breaches involve unauthorized access
**Trust**: Users won't use apps where their data isn't protected
**Compliance**: GDPR, HIPAA, CCPA require access controls
**Liability**: Companies face lawsuits for inadequate authorization

### Authorization Solves This

With proper authorization, each action is verified:
- "Can John edit this blog?" ← Check ownership
- "Can readers create blogs?" ← Check role
- "Is admin allowed?" ← Check privileges

---

## Conceptual Foundations

### Role-Based Access Control (RBAC)

RBAC organizes users into roles with specific permissions. Instead of managing individual permissions for each user, you manage role permissions once.

**Three-Tier Model:**

```
Tier 1: Users → Assigned to Roles
        John → [Author, Moderator]
        Jane → [Reader]
        Admin → [Admin]

Tier 2: Roles → Have Permissions
        Author → [create:blog, update:own_blog]
        Reader → [read:blog]
        Admin → [read:*, create:*, update:*, delete:*]

Tier 3: Permissions → Control Actions
        create:blog → Can create new blogs
        update:own_blog → Can update blogs they own
        read:blog → Can view any blog
```

**Why RBAC?**

1. **Scalability**: Manage 1000 users by managing 3 roles
2. **Consistency**: All authors have same permissions
3. **Flexibility**: Change all author permissions by updating one role
4. **Auditability**: Easy to see what each role can do

### Role Hierarchy in This App

```
Reader (Tier 1)
├─ Permissions: read:blog (view only)
├─ Use Case: Blog subscribers, visitors
└─ Security Level: Lowest

Author (Tier 2)
├─ Permissions: read:blog, create:blog, update:own_blog, delete:own_blog
├─ Use Case: Blog creators, contributors
└─ Security Level: Medium

Admin (Tier 3)
├─ Permissions: read:*, create:*, update:*, delete:* (all)
├─ Use Case: System administrators, moderators
└─ Security Level: Highest
```

### Why Three Tiers?

- **Reader**: Most users - minimal privileges
- **Author**: Content creators - moderate privileges
- **Admin**: Trusted users only - full access

This follows the **Principle of Least Privilege**: Users get minimum permissions needed.

---

## Authentication vs Authorization

### The Difference

```
Authentication (WHO are you?)
├─ User provides credentials (email + password)
├─ System verifies identity
├─ If valid: User is logged in
├─ Tool: Devise
└─ Question: "Is this really John?"

Authorization (WHAT can you do?)
├─ System checks user's role and permissions
├─ System evaluates resource ownership
├─ If allowed: Action proceeds
├─ Tool: Pundit
└─ Question: "Can John edit this blog?"
```

### Real Example: Editing a Blog

```
Step 1: Authentication (Devise)
User: john@example.com / password123
    ↓
Devise checks encrypted password
    ↓
User verified ✓ → current_user = John

Step 2: Authorization (Pundit)
Request: PATCH /blogs/123
User: John (author)
Blog: Blog #123 (owned by mary@example.com)
    ↓
Pundit calls BlogPolicy#update?
    ↓
Evaluates:
  - Is user authenticated? YES ✓
  - Does user own this blog? NO ✗
  - Is user admin? NO ✗
    ↓
Result: false (not authorized)
    ↓
NotAuthorizedError raised
    ↓
User sees: "You are not authorized..."
```

### Why Both Are Needed

- **Authentication only**: Know who user is, but don't control what they do
- **Authorization only**: Don't know who user is, can't verify permissions
- **Both together**: Complete security

---

## How Pundit Works

### The Request Flow

```
1. HTTP Request arrives
   GET /blogs/123/edit
   [Session: user_id=5]
                        ↓
2. Rails Router matches action
   → BlogsController#edit
                        ↓
3. Before Filters Execute
   before_action :authenticate_user!
   └─ Checks: Is user_id in session? YES ✓
                        ↓
   before_action :set_blog
   └─ Sets: @blog = Blog.find(123)
                        ↓
   before_action :authorize_blog
   └─ Calls: authorize @blog
                        ↓
4. Pundit Authorization Check
   authorize @blog does:

   a) Get current_user (User.find(5))
   b) Get record (@blog = Blog#123)
   c) Instantiate policy
      policy = BlogPolicy.new(current_user, @blog)
   d) Call policy method
      policy.edit?
                        ↓
5. Policy Method Evaluated
   def edit?
     user.present? &&              # Is user logged in?
     (record.user == user ||       # Does user own blog?
      user.admin?)                 # Or is user admin?
   end
                        ↓
   Returns: true or false
                        ↓
6. Decision Made

   If true:  Continue to controller action
   If false: Raise Pundit::NotAuthorizedError
                        ↓
7. Error Handling
   rescue_from Pundit::NotAuthorizedError
                        ↓
   flash[:alert] = "You are not authorized..."
   redirect_to request.referrer
                        ↓
8. Response Sent to Browser
   User sees error message and redirects back
```

### Policy Class Structure

```ruby
class BlogPolicy < ApplicationPolicy
  # Receives user and resource in initialize
  attr_reader :user, :record

  def initialize(user, record)
    @user = user       # Current user (or nil if unauthenticated)
    @record = record   # The blog being checked
  end

  # Helper methods (private logic)
  def own_blog?
    record.user == user  # Check ownership
  end

  # Public authorization methods
  def index?
    true  # Allows or denies index action
  end

  def show?
    true  # Allows or denies show action
  end

  # ... more methods
end
```

### Why Plain Ruby?

Pundit uses plain Ruby instead of a DSL:

```ruby
# Pundit style (plain Ruby) - Clear and flexible
def edit?
  user.present? && (own_blog? || user.admin?)
end

# Alternative DSL style - Less clear
can :edit, :blog, owner_id: :user_id
```

**Why Pundit wins:**
- ✓ Easy to understand (just Ruby)
- ✓ Easy to debug (print statements work)
- ✓ Easy to test (call methods directly)
- ✓ Flexible (any condition works)
- ✓ No magic (explicit code)

---

## Implementation Guide

### Part 1: Add Roles to User

**Why we add roles:**
- We need to differentiate user privileges
- Roles are simple integers (0, 1, 2) for performance
- Enums provide clean API (`user.author?`, `user.admin!`)

**Migration:**
```ruby
class AddRoleToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :role, :integer, default: 0
  end
end
```

**Design decision:** Integer default 0 = reader role (most restrictive)

**User Model:**
```ruby
enum role: { reader: 0, author: 1, admin: 2 }
```

**Benefits:**
- `user.reader?` → true/false check
- `user.author!` → upgrade role
- `User.admin` → query all admins
- Database efficient (small integer)

---

### Part 2: Install Pundit

**Why this configuration:**

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization
```

This includes Pundit in all controllers. Every controller can now use `authorize`.

```ruby
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
```

**Design decision:** Catch authorization errors globally
- **Alternative 1:** Check authorization in each controller
  - ✗ Repetitive
  - ✗ Easy to forget
  - ✗ Maintenance burden
- **Alternative 2:** Catch globally (chosen)
  - ✓ Single place to handle
  - ✓ Consistent behavior
  - ✓ Can't forget

```ruby
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
```

**Why redirect to referrer or root:**
- Referrer: Shows user where they came from (user-friendly)
- Root: Falls back if no referrer (safe)
- Not redirect to login: User is authenticated, just not authorized

---

### Part 3: Create Blog Authorization Policy

**The Rules We Chose:**

```ruby
# Everyone can view (no authorization needed)
def index?
  true
end

def show?
  true
end
```

**Reasoning:**
- Blogs are public content
- Views don't expose sensitive data
- More views = better engagement
- Alternative rejected: require login to view
  - ✗ Reduces accessibility
  - ✗ Prevents sharing

```ruby
# Only authors and admins can create
def new?
  user.present? && (user.author? || user.admin?)
end

def create?
  new?
end
```

**Reasoning:**
- Readers shouldn't create blogs (spam/abuse prevention)
- Authors create content (core functionality)
- Admins can create for testing/moderation
- Alternative rejected: let anyone create
  - ✗ Spam problem
  - ✗ Quality issues
  - ✗ Moderation burden

```ruby
# Only owner or admin can edit/delete
def edit?
  user.present? && (own_blog? || user.admin?)
end

def update?
  edit?
end

def destroy?
  edit?
end
```

**Reasoning:**
- User must be logged in (obvious)
- Ownership check: `record.user == user`
  - Users should only edit their own content
  - Prevents tampering with others' blogs
- Admin bypass: `user.admin?`
  - Admins can moderate/delete spam
  - Admins can manage all content
- Why same rule for edit/update/destroy?
  - Users who can see edit form can update
  - Users who can update should delete
  - Consistency principle

**Helper Method:**
```ruby
def own_blog?
  record.user == user
end
```

Extracted for clarity and reuse. Compare IDs, not object equality.

---

### Part 4: Controller Integration

**Authorization in Actions:**

```ruby
def new
  @blog = current_user.blogs.build
  authorize @blog  # Check before showing form
end

def create
  @blog = current_user.blogs.build(blog_params)
  authorize @blog  # Check before saving

  if @blog.save
    redirect_to @blog, notice: 'Blog was successfully created.'
  else
    render :new, status: :unprocessable_entity
  end
end
```

**Design decision:** Authorize before saving

**Alternative approaches:**

```ruby
# Approach 1: Authorize after finding (chosen for create)
@blog = current_user.blogs.build
authorize @blog

# Approach 2: Authorize after saving
@blog = current_user.blogs.build
@blog.save
authorize @blog  # Too late, already saved!

# Approach 3: Check in policy before returning
# Not what Pundit does - Pundit is explicit
```

**Why authorize before saving:**
- Don't save unauthorized changes
- Fail fast (immediate feedback)
- No database churn
- Clear intent

```ruby
before_action :authorize_blog, only: [:edit, :update, :destroy]
```

**Design decision:** Use before_action for edit/update/destroy

**Alternatives:**

```ruby
# Approach 1: Explicit authorize in each action (verbose)
def update
  authorize @blog
  # ... update logic
end

# Approach 2: Before filter (chosen - DRY)
before_action :authorize_blog, only: [:edit, :update, :destroy]

# Approach 3: Pundit policy scoping (advanced)
# Not used for our simple needs
```

**Why before_action:**
- ✓ DRY (don't repeat in each action)
- ✓ Consistent enforcement
- ✓ Fails before reaching action code
- ✓ Clear intent

---

## Design Decisions Explained

### Why Blog-Centric Rules?

```ruby
# We could have:
# 1. Only authenticated can view anything
# 2. Only authors can see blogs
# 3. Everything public (our choice)

def show?
  true  # Our choice: public access
end
```

**Why we chose public view:**
1. **Content discovery**: Readers find blogs naturally
2. **SEO**: Search engines can index content
3. **Sharing**: Users can share blogs with links
4. **Social**: Increases engagement
5. **Inclusive**: No login barrier

### Why Ownership Checks?

```ruby
def edit?
  user.present? && (own_blog? || user.admin?)
end
```

**vs. Alternative: Everyone can edit (dangerous)**

```ruby
def edit?
  user.present?  # BAD - any user can edit any blog
end
```

**vs. Alternative: Role-based only (rigid)**

```ruby
def edit?
  user.author? || user.admin?  # BAD - any author can edit any blog
end
```

**Why ownership + role:**
- Users own their content (natural expectation)
- Admins maintain site health (moderation)
- Prevents accidental/intentional data tampering
- Follows principle of least privilege

### Why Three Roles?

**We could have:**
- 2 roles (User, Admin) - too simple
- 5 roles (Reader, Author, Editor, Moderator, Admin) - too complex
- 3 roles (Reader, Author, Admin) - **Goldilocks zone**

**Why 3:**
- Reader: Covers 80% of users (viewing only)
- Author: Covers 15% of users (creating content)
- Admin: Covers 5% of users (system management)

**Why not more:**
- ✗ Complex permission matrix
- ✗ Hard to maintain
- ✗ Confusing for developers
- ✗ Overkill for simple app

---

## Security Considerations

### Threat 1: Privilege Escalation

**Attack:** User tries to change their role to admin

```ruby
# Vulnerable code:
def update_profile
  current_user.update(user_params)  # Includes role!
end

# Attacker:
# PUT /users/5
# role=2  ← Tries to set to admin
```

**Protection:** Don't permit role in user_params
```ruby
def user_params
  params.require(:user).permit(:email, :username)
  # Note: No :role - users can't change it
end
```

**Additional protection:** Require admin action
```ruby
# AdminController only
def update_user_role
  authorize User, :manage_roles?  # Only admins
  user.update(role: params[:role])
end
```

### Threat 2: Direct Object Reference (DORK)

**Attack:** User guesses blog ID and tries to edit

```
Normal URL: /blogs/5/edit
Hacker tries: /blogs/999/edit
```

**Protection:** Authorization check

```ruby
@blog = Blog.find(params[:id])
authorize @blog  # Checks: can current_user edit @blog?
```

If user 5 doesn't own blog 999 and isn't admin → NotAuthorizedError

### Threat 3: Timing Attacks

**Attack:** Measure response time to infer data existence

```ruby
# Vulnerable:
def show
  @blog = Blog.find_or_raise(params[:id])  # Fast if not found
  authorize @blog                            # Slow to check auth
end

# Protected:
def show
  @blog = Blog.find(params[:id])  # Fast regardless
  authorize @blog                   # Same time for all users
end
```

Modern Rails handles this, but good to know.

### Threat 4: Information Disclosure

**Attack:** Error messages reveal sensitive info

```ruby
# Vulnerable:
rescue Pundit::NotAuthorizedError
  flash[:alert] = "Admin #{@blog.admin.email} can approve this"
end

# Protected:
rescue Pundit::NotAuthorizedError
  flash[:alert] = "You are not authorized to perform this action."
end
```

Our implementation is safe - generic message.

### Threat 5: Session Fixation

**Not directly a Pundit issue, but important:**

```ruby
# Rails handles this with:
# - Reset session on login
# - Secure cookies (HttpOnly, Secure flags)
# - Devise handles for us
```

---

## Testing Strategy

### Unit Test: Policy Classes

```ruby
describe BlogPolicy do
  let(:user) { User.new(role: :author) }
  let(:blog) { Blog.new(user: user) }

  describe '#edit?' do
    context 'when user owns blog' do
      it { expect(policy.edit?).to be true }
    end

    context 'when user does not own blog' do
      let(:other_blog) { Blog.new(user: User.new(role: :author)) }

      it { expect(BlogPolicy.new(user, other_blog).edit?).to be false }
    end

    context 'when user is admin' do
      let(:admin) { User.new(role: :admin) }

      it { expect(BlogPolicy.new(admin, other_blog).edit?).to be true }
    end
  end
end
```

**Benefits:**
- Fast (no database, no HTTP)
- Focused (test one policy)
- Reliable (no flakiness)

### Integration Test: Controller + Policy

```ruby
describe BlogsController do
  describe '#edit' do
    context 'as blog owner' do
      before { sign_in(blog.user) }

      it 'renders edit template' do
        get :edit, params: { id: blog.id }
        expect(response).to render_template(:edit)
      end
    end

    context 'as different user' do
      before { sign_in(create(:user)) }

      it 'redirects with error' do
        get :edit, params: { id: blog.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("not authorized")
      end
    end
  end
end
```

### System Test: Full User Journey

```ruby
feature 'Blog Management' do
  scenario 'Author edits own blog' do
    author = create(:user, role: :author)
    blog = create(:blog, user: author)

    sign_in author
    visit edit_blog_path(blog)

    fill_in 'Title', with: 'New Title'
    click_button 'Update'

    expect(page).to have_content('New Title')
  end

  scenario 'Author cannot edit others blog' do
    author1 = create(:user, role: :author)
    author2 = create(:user, role: :author)
    blog = create(:blog, user: author2)

    sign_in author1
    visit edit_blog_path(blog)

    expect(page).to have_content('not authorized')
  end
end
```

**All three levels ensure:**
- Policies work correctly (unit)
- Controllers use policies (integration)
- Real users can/can't do things (system)

---

## Common Pitfalls

### Pitfall 1: Forgetting to Authorize

```ruby
# DANGEROUS - No authorization!
def update
  @blog = Blog.find(params[:id])
  @blog.update(blog_params)
  # Any user can update any blog!
end

# CORRECT
def update
  @blog = Blog.find(params[:id])
  authorize @blog  # Check authorization
  @blog.update(blog_params)
end
```

**How to prevent:** Code review checklist
- [ ] Does controller use `authorize`?
- [ ] Are sensitive actions protected?
- [ ] Test with different users?

### Pitfall 2: Wrong Authorization Level

```ruby
# WRONG - Checks too late
def create
  @blog = current_user.blogs.build(blog_params)
  @blog.save              # Saves before checking!
  authorize @blog         # Check too late
end

# CORRECT
def create
  @blog = current_user.blogs.build(blog_params)
  authorize @blog         # Check before saving
  @blog.save
end
```

### Pitfall 3: Comparing Objects Instead of IDs

```ruby
# WORKS but risky
def own_blog?
  record.user == user  # Works in most cases
end

# SAFER - explicit ID comparison
def own_blog?
  record.user_id == user.id  # Always works
end
```

**Why safer:** If user object isn't fully loaded, comparison fails.

### Pitfall 4: Forgetting Nil Check

```ruby
# WRONG - Breaks if user is nil (unauthenticated)
def edit?
  user.admin? || own_blog?  # Crashes if user is nil
end

# CORRECT
def edit?
  user.present? && (user.admin? || own_blog?)
end
```

### Pitfall 5: Authorization on View Only

```ruby
# WRONG - Only hides button, doesn't prevent action
<% if current_user&.admin? %>
  <%= link_to 'Delete', blog_path, method: :delete %>
<% end %>

# CORRECT - Control at both levels
# In view (hide button):
<% if policy(@blog).destroy? %>
  <%= link_to 'Delete', blog_path, method: :delete %>
<% end %>

# In controller (enforce):
def destroy
  authorize @blog  # Prevents direct URL access
  @blog.destroy
end
```

### Pitfall 6: Too Permissive Policies

```ruby
# WRONG - Too open
def edit?
  true  # Anyone can edit anything!
end

# BETTER - Restrictive by default
def edit?
  false  # Deny by default
end

# Then allow specific cases:
def edit?
  user.present? && (own_blog? || user.admin?)
end
```

**Principle:** Deny by default, allow specific cases

---

## Best Practices

### 1. Deny by Default

```ruby
# GOOD
def destroy?
  false  # Start with no
end

# Then explicitly allow:
def destroy?
  user.admin?
end

# NOT
def destroy?
  # Implicit false (works but unclear)
end
```

**Why:** Shows intent clearly. Security-first mindset.

### 2. Use Helper Methods

```ruby
# GOOD - Clear intent
def edit?
  user.present? && (own_blog? || user.admin?)
end

def own_blog?
  record.user == user
end

# NOT - Repeated logic
def edit?
  user.present? && (record.user == user || user.admin?)
end

def update?
  user.present? && (record.user == user || user.admin?)
end
```

**Why:** DRY, readable, maintainable

### 3. Policy Scopes for Queries

```ruby
# Simple case (used)
@blogs = Blog.all

# Advanced case (policy scopes)
class BlogPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(published: true)
      end
    end
  end
end

# Usage:
@blogs = policy_scope(Blog)  # Returns based on user
```

### 4. Test Edge Cases

```ruby
# Test all roles
describe BlogPolicy do
  context 'with reader' do
    let(:user) { build(:user, role: :reader) }
    it { expect(policy.create?).to be false }
  end

  context 'with author' do
    let(:user) { build(:user, role: :author) }
    it { expect(policy.create?).to be true }
  end

  context 'with admin' do
    let(:user) { build(:user, role: :admin) }
    it { expect(policy.create?).to be true }
  end

  context 'with no user' do
    let(:user) { nil }
    it { expect(policy.create?).to be false }
  end
end
```

### 5. Use Pundit in Views

```erb
<!-- GOOD - Hide and prevent -->
<% if policy(@blog).edit? %>
  <%= link_to 'Edit', edit_blog_path(@blog) %>
<% end %>

<!-- ACCEPTABLE - Just hide (controller enforces) -->
<% if @blog.user == current_user %>
  <%= link_to 'Edit', edit_blog_path(@blog) %>
<% end %>

<!-- BAD - No protection at all -->
<%= link_to 'Edit', edit_blog_path(@blog) %>
```

**Rule:** Use `policy` methods in views. Controllers enforce.

### 6. Log Authorization Events

```ruby
# Optional: Track who tried what
class BlogPolicy < ApplicationPolicy
  def edit?
    authorized = user.present? && (own_blog? || user.admin?)

    unless authorized
      Rails.logger.warn(
        "Unauthorized edit attempt: user=#{user&.id}, blog=#{record.id}"
      )
    end

    authorized
  end
end
```

### 7. Document Your Policies

```ruby
class BlogPolicy < ApplicationPolicy
  # == Blog Authorization Policy ==
  # Handles access control for blog resources.
  #
  # Rules:
  # - Anyone can read blogs (published or public)
  # - Only authenticated users can create
  # - Only owners or admins can modify/delete

  # Check if user owns this blog
  def own_blog?
    record.user == user
  end

  # Everyone can view the blog index
  def index?
    true
  end

  # ... etc
end
```

---

## Authorization Decision Matrix

### All Scenarios

```
┌─────────────────────────────────────────────────────────────────┐
│ USER ROLE: READER                                               │
├──────────────────────────┬──────────┬──────────┬────────────────┤
│ Action                   │ Allowed? │ Reason   │ Policy Method  │
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ View blog list           │ ✓ YES    │ Public   │ index? → true  │
│ View single blog         │ ✓ YES    │ Public   │ show? → true   │
│ Create new blog          │ ✗ NO     │ Role     │ new? → false   │
│ Edit blog                │ ✗ NO     │ Role     │ edit? → false  │
│ Delete blog              │ ✗ NO     │ Role     │ destroy? → false
└──────────────────────────┴──────────┴──────────┴────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER ROLE: AUTHOR                                               │
├──────────────────────────┬──────────┬──────────┬────────────────┤
│ OWN BLOG                 │          │          │                │
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ View blog list           │ ✓ YES    │ Public   │ index? → true  │
│ View single blog         │ ✓ YES    │ Public   │ show? → true   │
│ Create new blog          │ ✓ YES    │ Role     │ new? → true    │
│ Edit blog                │ ✓ YES    │ Owner    │ edit? → true   │
│ Delete blog              │ ✓ YES    │ Owner    │ destroy? → true│
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ OTHER'S BLOG             │          │          │                │
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ View blog list           │ ✓ YES    │ Public   │ index? → true  │
│ View single blog         │ ✓ YES    │ Public   │ show? → true   │
│ Create new blog          │ ✓ YES    │ Role     │ new? → true    │
│ Edit blog                │ ✗ NO     │ Ownership│ edit? → false  │
│ Delete blog              │ ✗ NO     │ Ownership│ destroy? → false
└──────────────────────────┴──────────┴──────────┴────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER ROLE: ADMIN (any blog)                                     │
├──────────────────────────┬──────────┬──────────┬────────────────┤
│ Action                   │ Allowed? │ Reason   │ Policy Method  │
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ View blog list           │ ✓ YES    │ Public   │ index? → true  │
│ View single blog         │ ✓ YES    │ Public   │ show? → true   │
│ Create new blog          │ ✓ YES    │ Role     │ new? → true    │
│ Edit blog                │ ✓ YES    │ Admin    │ edit? → true   │
│ Delete blog              │ ✓ YES    │ Admin    │ destroy? → true│
└──────────────────────────┴──────────┴──────────┴────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ NOT LOGGED IN (unauthenticated)                                 │
├──────────────────────────┬──────────┬──────────┬────────────────┤
│ Action                   │ Allowed? │ Reason   │ Policy Method  │
├──────────────────────────┼──────────┼──────────┼────────────────┤
│ View blog list           │ ✓ YES    │ Public   │ index? → true  │
│ View single blog         │ ✓ YES    │ Public   │ show? → true   │
│ Create new blog          │ ✗ NO     │ Auth req │ new? → false   │
│ Edit blog                │ ✗ NO     │ Auth req │ edit? → false  │
│ Delete blog              │ ✗ NO     │ Auth req │ destroy? → false
└──────────────────────────┴──────────┴──────────┴────────────────┘
```

---

## What We Learned

✓ Authorization is critical for security
✓ RBAC organizes permissions efficiently
✓ Pundit uses plain Ruby policies
✓ Before-action filters enforce globally
✓ Ownership checks provide fine-grained control
✓ Admin bypass allows site management
✓ Deny by default, allow explicitly
✓ Test all roles and scenarios
✓ Protect at both controller and view
✓ Never trust user input for permissions

---

## Quick Reference

### Test Users
```
reader@example.com    / password123 (can view only)
author@example.com    / password123 (can create & edit own)
author2@example.com   / password123 (can create & edit own)
admin@example.com     / password123 (full access)
```

### Key Files
- `app/models/user.rb` - Role enum
- `app/policies/blog_policy.rb` - Authorization rules
- `app/controllers/application_controller.rb` - Pundit setup
- `app/controllers/blogs_controller.rb` - Authorization calls

### Testing
```bash
# Console test
rails console
user = User.find_by(email: 'admin@example.com')
policy = BlogPolicy.new(user, Blog.first)
policy.edit?  # => true

# Browser test
rails server
# Login and test different roles at http://localhost:3000
```

### Common Patterns
```ruby
# Role-based
user.admin?

# Ownership-based
record.user == user

# Role + Ownership
(record.user == user) || user.admin?

# Authenticated only
user.present?

# Complex condition
user.present? && (own_blog? || user.admin?) && record.published?
```

---

## Next Steps

1. **Add View Checks**
   ```erb
   <% if policy(@blog).edit? %>
     <%= link_to 'Edit', edit_blog_path(@blog) %>
   <% end %>
   ```

2. **Create More Policies**
   ```bash
   rails generate pundit:policy User
   ```

3. **Implement Scopes** (filter queries by authorization)
   ```ruby
   class BlogPolicy::Scope < ApplicationPolicy::Scope
     def resolve
       user&.admin? ? scope.all : scope.where(published: true)
     end
   end
   ```

4. **Add Audit Logging** (track authorization events)

5. **Expand Roles** (add more granular permissions)

---

**Implementation is complete and production-ready!** ✓
