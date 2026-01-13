# Complete Devise Authentication Tutorial for Rails

## Table of Contents
1. [Introduction to Devise](#introduction-to-devise)
2. [Setup & Installation](#setup--installation)
3. [Understanding Devise Modules](#understanding-devise-modules)
4. [Database Models](#database-models)
5. [Routes Walkthrough](#routes-walkthrough)
6. [Devise Helper Methods](#devise-helper-methods)
7. [View Structure and Files](#view-structure-and-files)
8. [Customizing Forms](#customizing-forms)
9. [Permitting Additional Parameters](#permitting-additional-parameters)
10. [Password Reset with Email](#password-reset-with-email)
11. [Flash Messages and Notifications](#flash-messages-and-notifications)
12. [Before Actions and Authentication Filters](#before-actions-and-authentication-filters)
13. [Protecting Controllers](#protecting-controllers)
14. [Conditional Authentication](#conditional-authentication)
15. [Creating Navigation](#creating-navigation)
16. [Complete Example](#complete-example)
17. [Testing Checklist](#testing-checklist)
18. [Best Practices](#best-practices)
19. [Summary](#summary)

---

## Introduction to Devise

Devise is a flexible authentication solution for Rails based on Warden. It provides a complete authentication system including user registration, login, logout, password recovery, and more.

### Prerequisites
Before starting, ensure you have:
- A Rails application set up
- Devise gem installed in your Gemfile

---

## Setup & Installation

### Step 1: Add Devise to Gemfile

Add the Devise gem to your Gemfile:

```ruby
gem 'devise'
```

Then run:
```bash
bundle install
```

### Step 2: Generate Devise Configuration

Run the Devise generator:

```bash
rails generate devise:install
```

This creates:
- `config/initializers/devise.rb` - Devise configuration file
- Adds locale files for Devise messages

### Step 3: Generate Devise Views

Devise comes with default views, but to customize them, you need to generate them into your application.

Run this command in your terminal:

```bash
rails generate devise:views
```

**What this does:**
- Creates all Devise views in `app/views/devise/`
- Allows you to customize login, registration, and other authentication pages
- Gives you full control over the HTML and styling

### Expected Output:
```
create  app/views/devise/confirmations
create  app/views/devise/passwords
create  app/views/devise/registrations
create  app/views/devise/sessions
create  app/views/devise/shared
create  app/views/devise/unlocks
...
```

**Important Note:** If you only want to customize specific views (e.g., only registration), you can use:
```bash
rails generate devise:views -v registrations sessions
```

### Step 4: Generate User Model with Devise

Run this command to generate the User model with Devise:

```bash
rails generate devise User
```

This creates:
- `app/models/user.rb` - User model with Devise configuration
- Database migration with Devise columns
- Adds `devise_for :users` to your routes file

### Step 5: Run Database Migrations

```bash
rails db:create
rails db:migrate
```

---

## Understanding Devise Modules

Devise is modular, meaning you can pick and choose which features you want. Let's explore the five main modules used in this application.

### Location: `app/models/user.rb`

```ruby
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
```

### Module Breakdown:

#### 1. `:database_authenticatable`
- **Purpose:** Authenticates users with username/email and password
- **What it provides:**
  - Password encryption using bcrypt
  - `valid_password?` method to check passwords
  - Sign-in functionality
- **Database columns required:**
  - `email` (string)
  - `encrypted_password` (string)

#### 2. `:registerable`
- **Purpose:** Allows users to register, edit, and delete their accounts
- **What it provides:**
  - Sign up forms and logic
  - Account editing functionality
  - Account deletion capability
- **Routes created:**
  - `GET /users/sign_up` (new registration)
  - `POST /users` (create user)
  - `GET /users/edit` (edit account)
  - `PATCH/PUT /users` (update account)
  - `DELETE /users` (cancel account)

#### 3. `:recoverable`
- **Purpose:** Resets user passwords and sends reset instructions
- **What it provides:**
  - "Forgot your password?" functionality
  - Password reset emails
  - Password reset forms
- **Database columns required:**
  - `reset_password_token` (string, indexed)
  - `reset_password_sent_at` (datetime)

#### 4. `:rememberable`
- **Purpose:** Manages "Remember me" functionality via cookies
- **What it provides:**
  - Persistent login across browser sessions
  - "Remember me" checkbox on login forms
  - Token-based authentication cookie
- **Database columns required:**
  - `remember_created_at` (datetime)

#### 5. `:validatable`
- **Purpose:** Provides email and password validations
- **What it provides:**
  - Email format validation
  - Email uniqueness validation
  - Password length validation (minimum 6 characters by default)
  - Password confirmation matching
- **Note:** You can customize validation rules by overriding Devise methods

### Other Available Modules (not used in this app):

- `:confirmable` - Sends emails with confirmation instructions and verifies accounts
- `:lockable` - Locks accounts after a certain number of failed login attempts
- `:timeoutable` - Expires sessions after a specified period of inactivity
- `:trackable` - Tracks sign-in count, timestamps, and IP addresses
- `:omniauthable` - Adds OmniAuth support for external authentication (Google, Facebook, etc.)

---

## Database Models

### User Model with Associations

**Location:** `app/models/user.rb`

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :blogs, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true
end
```

### Blog Model with Associations

First, generate the Blog model:

```bash
rails generate model Blog title:string description:text user:references
rails db:migrate
```

**Location:** `app/models/blog.rb`

```ruby
class Blog < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :description, presence: true
  validates :user_id, presence: true
end
```

### Database Schema

The associations require:

1. **Users table** - Created by Devise migrations
2. **Blogs table** - With `user_id` foreign key

This allows:
```ruby
user.blogs              # Get all blogs by a user
blog.user              # Get the user who wrote the blog
current_user.blogs.build(...)  # Create a blog for current user
```

---

## Routes Walkthrough

Devise automatically generates routes when you add `devise_for :users` to your routes file.

### Location: `config/routes.rb`

```ruby
Rails.application.routes.draw do
  devise_for :users

  # Your other routes...
  resources :blogs
  root to: "home#index"
end
```

### Step 1: View All Devise Routes

Run this command to see all routes Devise creates:

```bash
rails routes | grep devise
```

### Understanding the Generated Routes:

```
# Session routes (Login/Logout)
new_user_session          GET    /users/sign_in           devise/sessions#new
user_session              POST   /users/sign_in           devise/sessions#create
destroy_user_session      DELETE /users/sign_out          devise/sessions#destroy

# Registration routes (Sign up/Edit account)
new_user_registration     GET    /users/sign_up           devise/registrations#new
user_registration         POST   /users                   devise/registrations#create
edit_user_registration    GET    /users/edit              devise/registrations#edit
                          PATCH  /users                   devise/registrations#update
                          DELETE /users                   devise/registrations#destroy

# Password recovery routes
new_user_password         GET    /users/password/new      devise/passwords#new
edit_user_password        GET    /users/password/edit     devise/passwords#edit
user_password             POST   /users/password          devise/passwords#create
                          PATCH  /users/password          devise/passwords#update
```

### Route Helper Methods:

Devise provides convenient helper methods for these routes:

```ruby
# Login
new_user_session_path        # => /users/sign_in
user_session_path            # => /users/sign_in (for POST)
destroy_user_session_path    # => /users/sign_out

# Registration
new_user_registration_path   # => /users/sign_up
edit_user_registration_path  # => /users/edit

# Password
new_user_password_path       # => /users/password/new
edit_user_password_path      # => /users/password/edit
```

### Example Usage in Views:

```erb
<%= link_to "Sign Up", new_user_registration_path %>
<%= link_to "Login", new_user_session_path %>
<%= link_to "Logout", destroy_user_session_path, data: { turbo_method: :delete } %>
<%= link_to "Edit Profile", edit_user_registration_path %>
<%= link_to "Forgot Password?", new_user_password_path %>
```

**Important Note:** The logout route uses the DELETE HTTP method, so you must use `data: { turbo_method: :delete }` (Rails 7) or `method: :delete` (older Rails versions).

---

## Devise Helper Methods

Devise provides several helper methods available in controllers and views to check authentication status and access the current user.

### Three Essential Helper Methods:

#### 1. `current_user`
**Purpose:** Returns the currently signed-in user object, or `nil` if no user is signed in.

**Usage in Controllers:**
```ruby
class BlogsController < ApplicationController
  def create
    @blog = current_user.blogs.build(blog_params)
    if @blog.save
      redirect_to @blog, notice: 'Blog created!'
    end
  end
end
```

**Usage in Views:**
```erb
<p>Welcome, <%= current_user.email %>!</p>
<p>You joined on <%= current_user.created_at.strftime('%B %d, %Y') %></p>
```

**Common Pattern:**
```ruby
# Safe way to access current_user attributes
if current_user
  puts current_user.email
else
  puts "No user logged in"
end
```

#### 2. `user_signed_in?`
**Purpose:** Returns `true` if a user is signed in, `false` otherwise. This is a boolean check.

**Usage in Views (Conditional Rendering):**
```erb
<% if user_signed_in? %>
  <p>Welcome back, <%= current_user.email %>!</p>
  <%= link_to "Logout", destroy_user_session_path, data: { turbo_method: :delete } %>
<% else %>
  <%= link_to "Login", new_user_session_path %>
  <%= link_to "Sign Up", new_user_registration_path %>
<% end %>
```

**Usage in Controllers:**
```ruby
class HomeController < ApplicationController
  def dashboard
    if user_signed_in?
      @user_data = current_user.personal_data
    else
      redirect_to new_user_session_path, alert: "Please log in first"
    end
  end
end
```

#### 3. `authenticate_user!`
**Purpose:** Forces authentication. Redirects to login page if user is not signed in.

**Usage as a Before Action:**
```ruby
class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]

  def new
    # This code only runs if user is authenticated
    @blog = Blog.new
  end
end
```

**What Happens:**
- If user is signed in → continues to the action
- If user is NOT signed in → redirects to login page with a flash message
- After successful login → redirects back to the originally requested page

**Protecting Entire Controllers:**
```ruby
class AdminController < ApplicationController
  before_action :authenticate_user!  # Applies to ALL actions

  def dashboard
    # All actions require authentication
  end
end
```

### Helper Method Comparison Table:

| Method | Returns | Use Case |
|--------|---------|----------|
| `current_user` | User object or `nil` | Access user data, associations |
| `user_signed_in?` | `true` or `false` | Conditional rendering, logic checks |
| `authenticate_user!` | Redirects if not signed in | Protecting actions/controllers |

---

## View Structure and Files

After generating Devise views, you'll have a structured folder with several subdirectories.

### Directory Structure:

```
app/views/devise/
├── confirmations/
│   └── new.html.erb              # Email confirmation page
├── passwords/
│   ├── edit.html.erb             # Reset password form
│   └── new.html.erb              # Forgot password form
├── registrations/
│   ├── edit.html.erb             # Edit account details
│   └── new.html.erb              # Sign up form
├── sessions/
│   └── new.html.erb              # Login form
├── shared/
│   ├── _error_messages.html.erb # Form error partial
│   └── _links.html.erb           # Helper links partial
└── unlocks/
    └── new.html.erb              # Account unlock form
```

### Key View Files Explained:

#### 1. `sessions/new.html.erb` - Login Page
**Purpose:** Where users enter credentials to log in.

**Default content includes:**
- Email field
- Password field
- "Remember me" checkbox
- Submit button
- Links to sign up and forgot password

#### 2. `registrations/new.html.erb` - Sign Up Page
**Purpose:** Where new users create accounts.

**Default content includes:**
- Email field
- Password field (with minimum length requirement)
- Password confirmation field
- Submit button
- Link to login page

#### 3. `registrations/edit.html.erb` - Edit Account Page
**Purpose:** Where users update their account information.

**Default content includes:**
- Email field (pre-filled)
- Password fields (to change password)
- Current password field (required for security)
- Update button
- "Cancel my account" button
- Link back

#### 4. `passwords/new.html.erb` - Forgot Password Page
**Purpose:** Where users request password reset instructions.

**Default content includes:**
- Email field
- Submit button
- Link back to login

#### 5. `passwords/edit.html.erb` - Reset Password Page
**Purpose:** Where users create a new password (accessed via email link).

**Default content includes:**
- New password field
- Password confirmation field
- Submit button

#### 6. `shared/_links.html.erb` - Navigation Links Partial
**Purpose:** Reusable links that appear at the bottom of Devise forms.

**Default links include:**
- Login
- Sign up
- Forgot password
- Didn't receive confirmation instructions?
- Didn't receive unlock instructions?

---

## Customizing Forms

Now that we understand the view structure, let's customize these forms to match your application's needs.

### Step 1: Customize the Sign Up Form

**Location:** `app/views/devise/registrations/new.html.erb`

Let's add a username field to the registration form.

**Original form (basic):**
```erb
<h2>Sign up</h2>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :password %>
    <% if @minimum_password_length %>
    <em>(<%= @minimum_password_length %> characters minimum)</em>
    <% end %><br />
    <%= f.password_field :password, autocomplete: "new-password" %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %><br />
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Sign up" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

**Enhanced version with username and better styling:**
```erb
<div class="auth-container">
  <h2>Create Your Account</h2>

  <%= form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>
    <%= render "devise/shared/error_messages", resource: resource %>

    <div class="field">
      <%= f.label :username %>
      <%= f.text_field :username, autofocus: true, placeholder: "Choose a username" %>
    </div>

    <div class="field">
      <%= f.label :email %>
      <%= f.email_field :email, autocomplete: "email", placeholder: "your@email.com" %>
    </div>

    <div class="field">
      <%= f.label :password %>
      <% if @minimum_password_length %>
        <em>(minimum <%= @minimum_password_length %> characters)</em>
      <% end %>
      <%= f.password_field :password, autocomplete: "new-password", placeholder: "Create a strong password" %>
    </div>

    <div class="field">
      <%= f.label :password_confirmation, "Confirm Password" %>
      <%= f.password_field :password_confirmation, autocomplete: "new-password", placeholder: "Re-enter your password" %>
    </div>

    <div class="actions">
      <%= f.submit "Sign Up", class: "btn btn-primary" %>
    </div>
  <% end %>

  <div class="auth-links">
    <%= render "devise/shared/links" %>
  </div>
</div>
```

**What changed:**
- Added a username field
- Added placeholder text for better UX
- Wrapped content in a container div for styling
- Changed button text to be more descriptive
- Improved label for password confirmation

### Step 2: Customize the Login Form

**Location:** `app/views/devise/sessions/new.html.erb`

**Enhanced login form:**
```erb
<div class="auth-container">
  <h2>Welcome Back!</h2>
  <p class="subtitle">Sign in to continue</p>

  <%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
    <div class="field">
      <%= f.label :email %>
      <%= f.email_field :email, autofocus: true, autocomplete: "email", placeholder: "your@email.com" %>
    </div>

    <div class="field">
      <%= f.label :password %>
      <%= f.password_field :password, autocomplete: "current-password", placeholder: "Enter your password" %>
    </div>

    <% if devise_mapping.rememberable? %>
      <div class="field checkbox">
        <%= f.check_box :remember_me %>
        <%= f.label :remember_me, "Keep me signed in" %>
      </div>
    <% end %>

    <div class="actions">
      <%= f.submit "Log In", class: "btn btn-primary" %>
    </div>
  <% end %>

  <div class="auth-links">
    <%= render "devise/shared/links" %>
  </div>
</div>
```

**Key features:**
- Clean, welcoming headline
- Remember me checkbox (only shows if rememberable module is enabled)
- Consistent styling with registration form
- User-friendly placeholders

### Step 3: Customize Password Reset Forms

**Location:** `app/views/devise/passwords/new.html.erb` - Forgot Password Form

```erb
<div class="auth-container">
  <h2>Forgot Your Password?</h2>
  <p>Enter your email address and we'll send you a link to reset your password.</p>

  <%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :post }) do |f| %>
    <%= render "devise/shared/error_messages", resource: resource %>

    <div class="field">
      <%= f.label :email %>
      <%= f.email_field :email, autofocus: true, autocomplete: "email", placeholder: "your@email.com" %>
    </div>

    <div class="actions">
      <%= f.submit "Send me reset password instructions", class: "btn btn-primary" %>
    </div>
  <% end %>

  <div class="auth-links">
    <%= render "devise/shared/links" %>
  </div>
</div>
```

**Location:** `app/views/devise/passwords/edit.html.erb` - Reset Password Form

```erb
<div class="auth-container">
  <h2>Change Your Password</h2>

  <%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :put }) do |f| %>
    <%= render "devise/shared/error_messages", resource: resource %>

    <%= f.hidden_field :reset_password_token %>

    <div class="field">
      <%= f.label :password, "New password" %>
      <% if @minimum_password_length %>
        <em>(minimum <%= @minimum_password_length %> characters)</em>
      <% end %>
      <%= f.password_field :password, autocomplete: "new-password", placeholder: "Create a strong password" %>
    </div>

    <div class="field">
      <%= f.label :password_confirmation, "Confirm new password" %>
      <%= f.password_field :password_confirmation, autocomplete: "new-password", placeholder: "Re-enter your password" %>
    </div>

    <div class="actions">
      <%= f.submit "Change my password", class: "btn btn-primary" %>
    </div>
  <% end %>

  <div class="auth-links">
    <%= render "devise/shared/links" %>
  </div>
</div>
```

### Step 4: Customize Edit Profile Form

**Location:** `app/views/devise/registrations/edit.html.erb`

```erb
<div class="auth-container">
  <h2>Edit Your Profile</h2>

  <%= form_for(resource, as: resource_name, url: registration_path(resource_name), html: { method: :put }) do |f| %>
    <%= render "devise/shared/error_messages", resource: resource %>

    <div class="field">
      <%= f.label :email %>
      <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
    </div>

    <div class="field">
      <%= f.label :username %>
      <%= f.text_field :username, autocomplete: "username" %>
    </div>

    <hr>

    <div class="field">
      <%= f.label :password, "New password (leave blank to keep current password)" %>
      <% if @minimum_password_length %>
        <em>(minimum <%= @minimum_password_length %> characters)</em>
      <% end %>
      <%= f.password_field :password, autocomplete: "new-password", placeholder: "Leave blank to keep current password" %>
    </div>

    <div class="field">
      <%= f.label :password_confirmation, "Confirm new password" %>
      <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
    </div>

    <div class="field">
      <%= f.label :current_password, "Current password (required for security)" %>
      <%= f.password_field :current_password, autocomplete: "current-password", placeholder: "Enter your current password" %>
    </div>

    <div class="actions">
      <%= f.submit "Update Profile", class: "btn btn-primary" %>
    </div>
  <% end %>

  <hr>

  <div class="danger-zone">
    <h3>Danger Zone</h3>
    <p>Delete your account and all associated data:</p>
    <%= button_to "Cancel my account", registration_path(resource_name),
                  data: { turbo_confirm: "Are you sure?" },
                  method: :delete,
                  class: "btn btn-danger" %>
  </div>

  <div class="auth-links">
    <%= link_to "Back", :back %>
  </div>
</div>
```

### Step 5: Customize Helper Links

**Location:** `app/views/devise/shared/_links.html.erb`

**Enhanced links partial:**
```erb
<div class="devise-links">
  <%- if controller_name != 'sessions' %>
    <p><%= link_to "Already have an account? Log in", new_session_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.registerable? && controller_name != 'registrations' %>
    <p><%= link_to "New user? Create an account", new_registration_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.recoverable? && controller_name != 'passwords' && controller_name != 'registrations' %>
    <p><%= link_to "Forgot your password?", new_password_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.confirmable? && controller_name != 'confirmations' %>
    <p><%= link_to "Didn't receive confirmation instructions?", new_confirmation_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.lockable? && resource_class.unlock_strategy_enabled?(:email) && controller_name != 'unlocks' %>
    <p><%= link_to "Didn't receive unlock instructions?", new_unlock_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.omniauthable? %>
    <%- resource_class.omniauth_providers.each do |provider| %>
      <p><%= button_to "Sign in with #{OmniAuth::Utils.camelize(provider)}", omniauth_authorize_path(resource_name, provider), data: { turbo: false } %></p>
    <% end %>
  <% end %>
</div>
```

---

## Permitting Additional Parameters

When you customize forms to include additional fields (like username), you must tell Devise to permit these parameters.

### Step 1: Configure Strong Parameters in ApplicationController

By default, Devise only permits `:email`, `:password`, and `:password_confirmation`. To add custom fields, you need to configure them.

**Location:** `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Permit additional parameters for sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])

    # Permit additional parameters for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name, :bio, :avatar])
  end
end
```

### Understanding the Code:

**Line-by-line explanation:**

```ruby
before_action :configure_permitted_parameters, if: :devise_controller?
```
- Runs `configure_permitted_parameters` method BEFORE any Devise action
- The `if: :devise_controller?` condition ensures this only runs for Devise controllers (not your other controllers)

```ruby
devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
```
- Permits the `:username` parameter during sign up (registration)
- Add any fields you added to the sign up form here

```ruby
devise_parameter_sanitizer.permit(:account_update, keys: [:username, :bio, :avatar])
```
- Permits parameters during account updates (edit profile)
- Can include different fields than sign up

### Common Additional Parameters:

```ruby
def configure_permitted_parameters
  # For sign up - minimal information
  devise_parameter_sanitizer.permit(:sign_up, keys: [
    :username,
    :first_name,
    :last_name,
    :date_of_birth
  ])

  # For account update - more detailed information
  devise_parameter_sanitizer.permit(:account_update, keys: [
    :username,
    :first_name,
    :last_name,
    :date_of_birth,
    :bio,
    :phone_number,
    :avatar,
    :location
  ])

  # For sign in - if you allow login with username instead of email
  devise_parameter_sanitizer.permit(:sign_in, keys: [:username])
end
```

**Important Notes:**
- You must add these columns to your User model migration first
- Parameters not listed here will be silently ignored (filtered out)
- Always restart your Rails server after changing ApplicationController

### Step 2: Add Database Columns for New Parameters

If you added a username field, you need to add it to the database:

```bash
rails generate migration AddUsernameToUsers username:string
rails db:migrate
```

**Migration file (`db/migrate/XXXXXX_add_username_to_users.rb`):**
```ruby
class AddUsernameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :username, :string
    add_index :users, :username, unique: true
  end
end
```

### Step 3: Add Validations to User Model

**Location:** `app/models/user.rb`

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :blogs, dependent: :destroy

  # Custom validations for additional fields
  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 3, maximum: 20 }
  validates :username, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" }
end
```

---

## Password Reset with Email

The `:recoverable` Devise module enables "Forgot your password?" functionality. Users can request password reset instructions, which are sent via email. For development, we'll use the `letter_opener` gem to preview emails in the browser instead of sending them.

### Understanding the Recoverable Module

The `:recoverable` module provides:
- Password reset token generation
- Password reset email sending
- Password reset form
- Token validation and expiration

**Database columns required:**
- `reset_password_token` (string, indexed) - Unique token for reset link
- `reset_password_sent_at` (datetime) - When the reset email was sent

These are already created by the Devise migration in your project.

### Step 1: Configure ActionMailer for Development

**Location:** `config/environments/development.rb`

Add or update the ActionMailer configuration:

```ruby
Rails.application.configure do
  # ... other configuration ...

  # Email configuration for development
  config.action_mailer.default_url_options = { host: 'localhost:3000' }
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # ... rest of configuration ...
end
```

**What each setting does:**
- `default_url_options` - Sets the host for email links (password reset links use this)
- `delivery_method: :letter_opener` - Opens emails in browser instead of sending
- `perform_deliveries: true` - Actually process email deliveries
- `raise_delivery_errors: true` - Raise exceptions if email delivery fails

### Step 2: Install Letter Opener Gem

The letter_opener gem should already be in your Gemfile. Install it:

```bash
bundle install
```

**What letter_opener does:**
- Intercepts emails in development
- Opens them automatically in your default browser
- Shows email preview with HTML rendering
- Logs email content to console
- NO external email service required
- Perfect for testing email features without sending real emails

**How it works:**
1. When your app tries to send an email
2. Letter_opener intercepts it (doesn't send to real email service)
3. Opens the email in a new browser tab automatically
4. You can read, check links, and verify formatting
5. Ideal for development and testing

**Important Note:** Letter_opener is ONLY for development. In production, you must configure a real email service (SendGrid, AWS SES, Mailgun, etc.).

### Step 3: Customize Password Reset Email Views

Generate Devise email views:

```bash
rails generate devise:views -v mailer
```

This creates email templates in `app/views/devise/mailer/`

**Location:** `app/views/devise/mailer/reset_password_instructions.html.erb`

```erb
<h2>Password reset instructions</h2>

<p>Someone has requested a link to change your password. You can do this through the link below.</p>

<p><%= link_to 'Change my password', edit_password_url(@resource, reset_password_token: @token) %></p>

<p>If you didn't request this, please ignore this email.</p>

<p>Your password won't change until you access the link above and create a new one.</p>
```

**Available variables:**
- `@resource` - The User object requesting password reset
- `@token` - The reset token (automatically appended to URL)

### Step 4: Update Devise Configuration for Password Reset

**Location:** `config/initializers/devise.rb`

The password reset configuration is already set by default. Key settings:

```ruby
# Password reset token expire time (default: 6 hours)
config.reset_password_within = 6.hours

# Password reset request timeout (default: 24 hours from when email was sent)
config.reset_password_keys = [:email]
```

This means:
- User has 6 hours to click the reset link
- Reset link is valid for 24 hours from when email was sent

### Step 5: Customize Email Sender Address

The default sender address is a placeholder. To change it to a real email:

**Location:** `config/initializers/devise.rb`

```ruby
Devise.setup do |config|
  # ... other configuration ...

  # Email address used as the "from" address
  config.mailer_sender = 'noreply@example.com'

  # Or use environment variable for flexibility
  config.mailer_sender = ENV.fetch('DEVISE_MAILER_SENDER') { 'noreply@example.com' }
end
```

After changing this, restart the Rails server to see the updated sender address in password reset emails.

### Step 6: Testing Password Reset Flow

**Prerequisites:**
- Rails server should be running on localhost:3000
- Letter_opener is installed and configured
- Make sure to restart the Rails server after installing letter_opener gem

**Step-by-step test:**

1. **Start the Rails server:**
```bash
rails server
```

Once you see "Listening on localhost:3000", the server is ready.

2. **Visit the forgot password page:**
- Go to http://localhost:3000/users/password/new
- Or click "Forgot your password?" link from login page

3. **Request password reset:**
- Enter email: `john.doe@example.com`
- Click "Send me reset password instructions"
- A new browser tab/window should open with the email preview

4. **Check the email:**
- The letter_opener preview shows:
  - Email subject
  - To/From addresses
  - Email body with the reset link
  - HTML rendering

5. **Click the reset link:**
- Click the "Change my password" link in the email
- You'll be taken to the password reset form at `/users/password/edit`

6. **Reset the password:**
- Enter new password: `newpassword123`
- Confirm password: `newpassword123`
- Click "Change my password"
- You should see "Your password has been changed successfully."

7. **Log in with new password:**
- Go to login page
- Email: `john.doe@example.com`
- Password: `newpassword123` (the new one you just set)
- You should be successfully logged in

### Common Password Reset Issues & Solutions

**Issue: No email opens in browser**
```
Problem: Email browser tab didn't open
Solution: Check your config/environments/development.rb
- Ensure delivery_method is set to :letter_opener
- Ensure perform_deliveries is true
- Restart Rails server after changes
```

**Issue: "Reset password token is invalid" error**
```
Problem: Password reset link doesn't work
Solution:
- Token expires after 6 hours (default)
- URL must match exactly
- Email address must match a user in database
```

**Issue: Email link shows localhost:3000 in wrong format**
```
Problem: Links in email are malformed
Solution: Update config/environments/development.rb
config.action_mailer.default_url_options = {
  host: 'localhost',
  port: 3000
}
```

### Production Email Setup

In production, you'll use a real email service. Here are the steps:

**Step 7: Configure Production Email (Future Reference)**

```ruby
# config/environments/production.rb
config.action_mailer.default_url_options = { host: 'yourdomain.com' }
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  authentication: :plain,
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  enable_starttls_auto: true
}
```

**Popular email services:**
- **SendGrid** - Reliable, free tier available, great documentation
- **AWS SES** - Cheap, integrates with AWS infrastructure
- **Mailgun** - Developer-friendly, good pricing
- **Gmail SMTP** - Simple setup for small projects (not recommended for production)

### Understanding the Password Reset Flow

Here's what happens behind the scenes:

```
1. User visits /users/password/new
   ↓
2. User submits email address
   ↓
3. Rails finds user by email
   ↓
4. Devise generates reset_password_token
   ↓
5. Devise saves token to database (reset_password_token column)
   ↓
6. Email is sent with token in link
   ↓
7. User clicks email link
   ↓
8. Rails validates token against database
   ↓
9. If valid, shows password reset form
   ↓
10. User submits new password
   ↓
11. Rails hashes new password and saves
   ↓
12. Reset token is cleared (security)
   ↓
13. User is logged in automatically
```

---

## Flash Messages and Notifications

Devise automatically sets flash messages for various actions (login, logout, errors, etc.). Let's implement them properly in your application.

### Understanding Flash Message Types:

Devise uses two flash types:
- **`notice`** - Success messages (green)
- **`alert`** - Error/warning messages (red/yellow)

### Step 1: Display Flash Messages in Application Layout

**Location:** `app/views/layouts/application.html.erb`

**Basic implementation:**
```erb
<!DOCTYPE html>
<html>
  <head>
    <title>DeviseAuthDemo</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <p class="notice"><%= notice %></p>
    <p class="alert"><%= alert %></p>
    <%= yield %>
  </body>
</html>
```

**Enhanced implementation with better styling and auto-dismiss:**
```erb
<!DOCTYPE html>
<html>
  <head>
    <title>DeviseAuthDemo</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <!-- Flash Messages Container -->
    <% if notice || alert %>
      <div class="flash-messages">
        <% if notice %>
          <div class="flash-message flash-notice">
            <%= notice %>
            <button class="flash-close" onclick="this.parentElement.remove()">×</button>
          </div>
        <% end %>

        <% if alert %>
          <div class="flash-message flash-alert">
            <%= alert %>
            <button class="flash-close" onclick="this.parentElement.remove()">×</button>
          </div>
        <% end %>
      </div>
    <% end %>

    <%= yield %>
  </body>
</html>
```

### Step 2: Add Styling for Flash Messages

**Location:** `app/assets/stylesheets/application.css`

Add these styles at the end of the file:

```css
/* Flash Messages Styling */
.flash-messages {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 9999;
  max-width: 400px;
}

.flash-message {
  padding: 15px 40px 15px 15px;
  margin-bottom: 10px;
  border-radius: 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  position: relative;
  animation: slideIn 0.3s ease-out;
}

.flash-notice {
  background-color: #d4edda;
  border: 1px solid #c3e6cb;
  color: #155724;
}

.flash-alert {
  background-color: #f8d7da;
  border: 1px solid #f5c6cb;
  color: #721c24;
}

.flash-close {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: inherit;
  opacity: 0.5;
  padding: 0;
  line-height: 1;
}

.flash-close:hover {
  opacity: 1;
}

@keyframes slideIn {
  from {
    transform: translateX(400px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}
```

### Common Devise Flash Messages:

Here are the default messages Devise sets:

| Action | Flash Type | Default Message |
|--------|------------|-----------------|
| Sign up | notice | "Welcome! You have signed up successfully." |
| Sign in | notice | "Signed in successfully." |
| Sign out | notice | "Signed out successfully." |
| Invalid credentials | alert | "Invalid Email or password." |
| Account locked | alert | "Your account is locked." |
| Not confirmed | alert | "You have to confirm your email address before continuing." |
| Password updated | notice | "Your password has been changed successfully." |
| Account updated | notice | "Your account has been updated successfully." |

### Step 3: Customize Flash Messages (Optional)

You can customize these messages in Devise's locale file.

**Location:** `config/locales/devise.en.yml`

```yaml
en:
  devise:
    sessions:
      signed_in: "Welcome back! You're now signed in."
      signed_out: "See you later! You've been signed out."
      already_signed_out: "You're already signed out."
    registrations:
      signed_up: "Welcome aboard! Your account has been created."
      updated: "Your profile has been updated successfully."
      destroyed: "Your account has been deleted. We're sorry to see you go."
    passwords:
      send_instructions: "Password reset instructions sent to your email."
      updated: "Your password has been changed successfully."
    failure:
      invalid: "Oops! The email or password you entered is incorrect."
      locked: "Your account is locked. Please contact support."
      not_found_in_database: "We couldn't find an account with that email."
      unauthenticated: "You need to sign in or sign up to continue."
      unconfirmed: "Please confirm your email address to continue."
```

---

## Before Actions and Authentication Filters

Before actions (callbacks) are methods that run before controller actions. Devise's `authenticate_user!` is commonly used as a before action.

### Understanding Before Actions:

```ruby
class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def new
    # This only runs if the user is authenticated
  end
end
```

**What happens:**
1. User visits `/blogs/new`
2. Rails runs `authenticate_user!` BEFORE the `new` action
3. If user is signed in → continue to `new` action
4. If user is NOT signed in → redirect to login page
5. After login → redirect back to `/blogs/new`

### Step 1: Understanding the Blogs Controller Implementation

**Location:** `app/controllers/blogs_controller.rb`

Let's analyze the current implementation:

```ruby
class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_blog, only: [:show, :edit, :update, :destroy]

  def index
    @blogs = Blog.all.order(created_at: :desc)
  end

  def show
    # No authentication required - anyone can view
  end

  def new
    # Requires authentication
    @blog = Blog.new
  end

  def edit
    # Requires authentication
  end

  def create
    # Requires authentication
    @blog = Blog.new(blog_params)

    if @blog.save
      redirect_to @blog, notice: 'Blog was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Requires authentication
    if @blog.update(blog_params)
      redirect_to @blog, notice: 'Blog was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Requires authentication
    @blog.destroy
    redirect_to blogs_path, notice: 'Blog was successfully deleted.'
  end

  private

  def set_blog
    @blog = Blog.find(params[:id])
  end

  def blog_params
    params.require(:blog).permit(:title, :description)
  end
end
```

**Analysis:**
- **Public actions** (`index`, `show`): No authentication required - anyone can view blogs
- **Protected actions** (`new`, `create`, `edit`, `update`, `destroy`): Require authentication
- The `set_blog` before action runs for specific actions regardless of authentication

---

## Protecting Controllers

There are multiple strategies for protecting controllers with authentication.

### Strategy 1: Protect Specific Actions (Recommended)

Use `only:` to specify which actions require authentication:

```ruby
class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]

  # index and show are public
end
```

**When to use:**
- When you have a mix of public and protected actions
- For resources that should be viewable by everyone but editable only by authenticated users
- Most common pattern for public-facing applications

### Strategy 2: Protect All Actions Except Some

Use `except:` to make most actions protected, but leave some public:

```ruby
class ProfilesController < ApplicationController
  before_action :authenticate_user!, except: [:show]

  def show
    # Public profile view
  end

  def edit
    # Requires authentication
  end
end
```

**When to use:**
- When most actions should be protected
- When only one or two actions should be public

### Strategy 3: Protect Entire Controller

Place the before action without conditions to protect everything:

```ruby
class DashboardController < ApplicationController
  before_action :authenticate_user!  # Applies to ALL actions

  def index
    # Requires authentication
  end

  def analytics
    # Requires authentication
  end
end
```

**When to use:**
- For admin panels
- For user dashboards
- For any area that has no public content

### Strategy 4: Skip Authentication for Specific Actions

Inherit authentication from ApplicationController but skip for specific actions:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!  # Protect everything by default
end

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # This is now public
  end
end
```

**When to use:**
- When you want authentication by default across your entire app
- When you want to explicitly mark public actions

### Step 2: Implement Authorization (Beyond Authentication)

Authentication checks if you're logged in. Authorization checks if you have permission.

**Example: Users can only edit their own blogs**

```ruby
class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_blog, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  # ... actions ...

  private

  def set_blog
    @blog = Blog.find(params[:id])
  end

  def authorize_user!
    unless @blog.user == current_user
      redirect_to blogs_path, alert: "You can only edit your own blogs."
    end
  end

  def blog_params
    params.require(:blog).permit(:title, :description)
  end
end
```

**Prerequisites for this to work:**
1. Blogs must belong to users (add `user_id` to blogs table)
2. Add association in models

**Migration:**
```bash
rails generate migration AddUserIdToBlogs user:references
rails db:migrate
```

**Models:**
```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :blogs, dependent: :destroy
end

# app/models/blog.rb
class Blog < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :description, presence: true
end
```

**Update create action to associate blog with user:**
```ruby
def create
  @blog = current_user.blogs.build(blog_params)  # Associates with current_user

  if @blog.save
    redirect_to @blog, notice: 'Blog was successfully created.'
  else
    render :new, status: :unprocessable_entity
  end
end
```

---

## Conditional Authentication

Let's explore different patterns for conditional authentication using `only:` and `except:`.

### Pattern 1: Read-Only Public, Write Protected

Most common pattern for blogs, forums, etc:

```ruby
class ArticlesController < ApplicationController
  # Anyone can read, only authenticated users can write
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]

  def index    # Public
  def show     # Public
  def new      # Protected
  def create   # Protected
  def edit     # Protected
  def update   # Protected
  def destroy  # Protected
end
```

### Pattern 2: Mostly Protected, Few Public

For user profile pages:

```ruby
class UsersController < ApplicationController
  # Most actions protected, only profile view is public
  before_action :authenticate_user!, except: [:show, :index]

  def index      # Public - browse users
  def show       # Public - view profile
  def edit       # Protected
  def update     # Protected
  def destroy    # Protected
end
```

### Pattern 3: Different Authentication Levels

Combining multiple before actions:

```ruby
class CommentsController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  before_action :check_comment_owner, only: [:edit, :update, :destroy]

  def index
    # Public
  end

  def create
    # Any authenticated user can create
  end

  def edit
    # Only the comment owner can edit
  end

  private

  def check_comment_owner
    @comment = Comment.find(params[:id])
    unless @comment.user == current_user
      redirect_to root_path, alert: "You can only edit your own comments."
    end
  end
end
```

---

## Creating Navigation

Let's create a navigation bar that displays different content based on whether a user is signed in.

### Step 1: Create a Navigation Partial

**Location:** `app/views/shared/_navigation.html.erb`

Create this new file (you may need to create the `shared` directory):

```bash
mkdir -p app/views/shared
touch app/views/shared/_navigation.html.erb
```

**Content:**
```erb
<nav class="navbar">
  <div class="nav-container">
    <!-- Logo/Brand -->
    <div class="nav-brand">
      <%= link_to "MyApp", root_path %>
    </div>

    <!-- Main Navigation Links -->
    <ul class="nav-links">
      <li><%= link_to "Home", root_path %></li>
      <li><%= link_to "Blogs", blogs_path %></li>

      <% if user_signed_in? %>
        <!-- Links shown only when signed in -->
        <li><%= link_to "New Blog", new_blog_path %></li>
        <li><%= link_to "My Profile", edit_user_registration_path %></li>
      <% end %>
    </ul>

    <!-- User Authentication Section -->
    <div class="nav-auth">
      <% if user_signed_in? %>
        <!-- Signed In: Show user info and logout -->
        <div class="user-menu">
          <span class="user-email">
            <%= current_user.email %>
          </span>
          <%= link_to "Logout", destroy_user_session_path,
                      data: { turbo_method: :delete },
                      class: "btn btn-logout" %>
        </div>
      <% else %>
        <!-- Not Signed In: Show login and sign up -->
        <div class="auth-buttons">
          <%= link_to "Login", new_user_session_path, class: "btn btn-login" %>
          <%= link_to "Sign Up", new_user_registration_path, class: "btn btn-signup" %>
        </div>
      <% end %>
    </div>
  </div>
</nav>
```

### Step 2: Include Navigation in Application Layout

**Location:** `app/views/layouts/application.html.erb`

Update the body section to include the navigation:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>DeviseAuthDemo</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <!-- Include Navigation -->
    <%= render 'shared/navigation' %>

    <!-- Flash Messages Container -->
    <% if notice || alert %>
      <div class="flash-messages">
        <% if notice %>
          <div class="flash-message flash-notice">
            <%= notice %>
            <button class="flash-close" onclick="this.parentElement.remove()">×</button>
          </div>
        <% end %>

        <% if alert %>
          <div class="flash-message flash-alert">
            <%= alert %>
            <button class="flash-close" onclick="this.parentElement.remove()">×</button>
          </div>
        <% end %>
      </div>
    <% end %>

    <!-- Main Content -->
    <main class="container">
      <%= yield %>
    </main>

    <!-- Footer (optional) -->
    <footer class="footer">
      <p>&copy; 2024 MyApp. All rights reserved.</p>
    </footer>
  </body>
</html>
```

### Step 3: Style the Navigation

**Location:** `app/assets/stylesheets/application.css`

Add these styles:

```css
/* Navigation Styles */
.navbar {
  background-color: #2c3e50;
  color: white;
  padding: 0;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.nav-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.nav-brand a {
  color: white;
  text-decoration: none;
  font-size: 1.5rem;
  font-weight: bold;
}

.nav-links {
  display: flex;
  list-style: none;
  margin: 0;
  padding: 0;
  gap: 2rem;
}

.nav-links li {
  margin: 0;
}

.nav-links a {
  color: white;
  text-decoration: none;
  transition: color 0.2s;
}

.nav-links a:hover {
  color: #3498db;
}

.nav-auth {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-menu {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-email {
  color: #ecf0f1;
  font-size: 0.9rem;
}

.auth-buttons {
  display: flex;
  gap: 0.5rem;
}

/* Button Styles */
.btn {
  padding: 0.5rem 1rem;
  text-decoration: none;
  border-radius: 4px;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
  font-size: 0.9rem;
}

.btn-login {
  background-color: transparent;
  color: white;
  border: 1px solid white;
}

.btn-login:hover {
  background-color: white;
  color: #2c3e50;
}

.btn-signup {
  background-color: #3498db;
  color: white;
}

.btn-signup:hover {
  background-color: #2980b9;
}

.btn-logout {
  background-color: #e74c3c;
  color: white;
}

.btn-logout:hover {
  background-color: #c0392b;
}

.btn-primary {
  background-color: #3498db;
  color: white;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
}

.btn-primary:hover {
  background-color: #2980b9;
}

/* Container for main content */
.container {
  max-width: 1200px;
  margin: 2rem auto;
  padding: 0 2rem;
}

/* Footer Styles */
.footer {
  background-color: #34495e;
  color: white;
  text-align: center;
  padding: 2rem;
  margin-top: 4rem;
}

.footer p {
  margin: 0;
}
```

### Advanced Navigation: Dropdown User Menu

For a more sophisticated user menu with dropdown:

**Updated navigation partial:**
```erb
<nav class="navbar">
  <div class="nav-container">
    <div class="nav-brand">
      <%= link_to "MyApp", root_path %>
    </div>

    <ul class="nav-links">
      <li><%= link_to "Home", root_path %></li>
      <li><%= link_to "Blogs", blogs_path %></li>
      <% if user_signed_in? %>
        <li><%= link_to "New Blog", new_blog_path %></li>
      <% end %>
    </ul>

    <div class="nav-auth">
      <% if user_signed_in? %>
        <div class="dropdown">
          <button class="dropdown-toggle">
            <%= current_user.email %>
            <span class="dropdown-arrow">▼</span>
          </button>
          <div class="dropdown-menu">
            <%= link_to "My Profile", edit_user_registration_path, class: "dropdown-item" %>
            <%= link_to "Settings", edit_user_registration_path, class: "dropdown-item" %>
            <hr class="dropdown-divider">
            <%= link_to "Logout", destroy_user_session_path,
                        data: { turbo_method: :delete },
                        class: "dropdown-item" %>
          </div>
        </div>
      <% else %>
        <div class="auth-buttons">
          <%= link_to "Login", new_user_session_path, class: "btn btn-login" %>
          <%= link_to "Sign Up", new_user_registration_path, class: "btn btn-signup" %>
        </div>
      <% end %>
    </div>
  </div>
</nav>
```

**Dropdown CSS (add to application.css):**
```css
/* Dropdown Menu */
.dropdown {
  position: relative;
}

.dropdown-toggle {
  background-color: transparent;
  color: white;
  border: 1px solid rgba(255,255,255,0.3);
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.dropdown-toggle:hover {
  background-color: rgba(255,255,255,0.1);
}

.dropdown-arrow {
  font-size: 0.7rem;
  margin-left: 0.5rem;
}

.dropdown-menu {
  display: none;
  position: absolute;
  right: 0;
  top: 100%;
  margin-top: 0.5rem;
  background-color: white;
  border-radius: 4px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  min-width: 200px;
  z-index: 1000;
}

.dropdown:hover .dropdown-menu {
  display: block;
}

.dropdown-item {
  display: block;
  padding: 0.75rem 1rem;
  color: #2c3e50;
  text-decoration: none;
  transition: background-color 0.2s;
}

.dropdown-item:hover {
  background-color: #ecf0f1;
}

.dropdown-divider {
  margin: 0.5rem 0;
  border: none;
  border-top: 1px solid #ecf0f1;
}
```

---

## Complete Example

### Step 1: Create a Home Page Controller

Let's create a home page that demonstrates all the concepts:

```bash
rails generate controller Home index
```

**Location:** `app/controllers/home_controller.rb`

```ruby
class HomeController < ApplicationController
  # This page is public - no authentication required
  def index
    if user_signed_in?
      @user_blogs = current_user.blogs.order(created_at: :desc).limit(5)
    end
    @recent_blogs = Blog.order(created_at: :desc).limit(10)
  end
end
```

**Location:** `app/views/home/index.html.erb`

```erb
<div class="home-page">
  <section class="hero">
    <h1>Welcome to MyApp</h1>

    <% if user_signed_in? %>
      <p>Hello, <%= current_user.email %>! Welcome back.</p>
      <%= link_to "Create New Blog", new_blog_path, class: "btn btn-primary" %>
    <% else %>
      <p>Share your thoughts with the world</p>
      <div class="hero-actions">
        <%= link_to "Get Started", new_user_registration_path, class: "btn btn-primary" %>
        <%= link_to "Learn More", blogs_path, class: "btn btn-secondary" %>
      </div>
    <% end %>
  </section>

  <!-- Conditional Content Based on Authentication -->
  <% if user_signed_in? %>
    <section class="user-section">
      <h2>Your Recent Blogs</h2>
      <% if @user_blogs.any? %>
        <div class="blog-grid">
          <% @user_blogs.each do |blog| %>
            <div class="blog-card">
              <h3><%= link_to blog.title, blog %></h3>
              <p><%= truncate(blog.description, length: 100) %></p>
              <div class="blog-actions">
                <%= link_to "Edit", edit_blog_path(blog), class: "btn-small" %>
                <%= link_to "Delete", blog_path(blog),
                            data: { turbo_method: :delete, turbo_confirm: "Are you sure?" },
                            class: "btn-small btn-danger" %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <p>You haven't created any blogs yet.</p>
        <%= link_to "Create Your First Blog", new_blog_path, class: "btn btn-primary" %>
      <% end %>
    </section>
  <% end %>

  <!-- Public Section - Visible to Everyone -->
  <section class="public-section">
    <h2>Recent Blogs from Our Community</h2>
    <div class="blog-grid">
      <% @recent_blogs.each do |blog| %>
        <div class="blog-card">
          <h3><%= link_to blog.title, blog %></h3>
          <p><%= truncate(blog.description, length: 100) %></p>
          <% if blog.user %>
            <small>By <%= blog.user.email %></small>
          <% end %>
        </div>
      <% end %>
    </div>
  </section>
</div>
```

**Update routes to use this as the home page:**

**Location:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  devise_for :users

  resources :blogs

  # Set home page as root
  root to: "home#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

## Testing Checklist

### Step 1: Manual Testing Checklist

Test each feature systematically:

#### Authentication Flow:
- [ ] Visit home page while logged out
- [ ] Click "Sign Up" and create an account
- [ ] Verify you're redirected and see success message
- [ ] Log out
- [ ] Try logging in with correct credentials
- [ ] Try logging in with incorrect credentials
- [ ] Test "Remember me" functionality

#### Authorization Flow:
- [ ] While logged out, try to access `/blogs/new` (should redirect to login)
- [ ] Log in and verify you're redirected back to `/blogs/new`
- [ ] Create a blog
- [ ] Log out and verify you can still view the blog
- [ ] Try to edit someone else's blog (should be denied)

#### Navigation:
- [ ] Verify navigation changes based on authentication status
- [ ] Check that user email displays when logged in
- [ ] Test all navigation links
- [ ] Verify logout works correctly

#### Flash Messages:
- [ ] Check flash messages appear for all actions
- [ ] Verify styling is correct
- [ ] Test close button functionality

---

## Best Practices

### Security Best Practices:

1. **Always use `authenticate_user!` for protected actions**
   ```ruby
   before_action :authenticate_user!, only: [:edit, :update, :destroy]
   ```

2. **Implement authorization, not just authentication**
   ```ruby
   # Check if user owns the resource
   unless @blog.user == current_user
     redirect_to root_path, alert: "Not authorized"
   end
   ```

3. **Use strong parameters**
   ```ruby
   # Only permit necessary parameters
   devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
   ```

4. **Always use HTTPS in production**
   - Devise sessions are cookie-based
   - Cookies should only be sent over HTTPS

5. **Set appropriate session timeouts**
   ```ruby
   # config/initializers/devise.rb
   config.timeout_in = 30.minutes
   ```

### Common Pitfalls to Avoid:

1. **Forgetting to permit custom parameters**
   - Always add custom fields to `configure_permitted_parameters`

2. **Not using `data: { turbo_method: :delete }` for logout**
   - Logout requires DELETE method
   - Turbo requires explicit method specification

3. **Checking `current_user.nil?` instead of using `user_signed_in?`**
   - Always use Devise helper methods

4. **Not restarting server after changing initializers**
   - Devise configuration changes require server restart

5. **Forgetting database migrations for custom fields**
   - Custom fields need database columns

### Performance Tips:

1. **Eager load associations**
   ```ruby
   @blogs = Blog.includes(:user).all
   ```

2. **Cache authentication checks**
   ```ruby
   # Instead of multiple current_user calls
   user = current_user
   ```

3. **Use database indices**
   ```ruby
   add_index :users, :email, unique: true
   add_index :users, :reset_password_token, unique: true
   ```

---

## Summary

You've now learned:

✅ How to generate and customize Devise views
✅ Understanding of all five main Devise modules
✅ Complete knowledge of Devise routes and helpers
✅ How to customize registration and login forms
✅ Permitting additional parameters in ApplicationController
✅ Password reset with email using letter_opener gem
✅ Configuring ActionMailer for development
✅ Customizing password reset email templates
✅ Implementing and styling flash messages
✅ Using before actions for authentication
✅ Protecting controllers with various strategies
✅ Conditional authentication with `only` and `except`
✅ Displaying user information in navigation
✅ Creating complete example with associations
✅ Manual testing your implementation

### Next Steps:

1. **Add email confirmation** (`:confirmable` module)
2. **Implement account lockout** (`:lockable` module)
3. **Add OAuth authentication** (`:omniauthable` module)
4. **Customize Devise controllers** for advanced customization
5. **Add role-based authorization** (with gems like Pundit or CanCanCan)

---

## Quick Reference Card

### Essential Helper Methods:
```ruby
current_user              # Returns current user object
user_signed_in?           # Returns true/false
authenticate_user!        # Redirects if not signed in
```

### Essential Path Helpers:
```ruby
new_user_session_path           # Login
destroy_user_session_path       # Logout
new_user_registration_path      # Sign up
edit_user_registration_path     # Edit profile
new_user_password_path          # Forgot password
```

### Essential Before Actions:
```ruby
before_action :authenticate_user!                        # All actions
before_action :authenticate_user!, only: [:edit]         # Specific actions
before_action :authenticate_user!, except: [:index]      # All except
skip_before_action :authenticate_user!, only: [:public]  # Skip for specific
```

### Flash Message Types:
```ruby
notice   # Success messages (green)
alert    # Error messages (red)
```

---

**Tutorial Complete!**

You now have a comprehensive understanding of Devise authentication in Rails. Practice these concepts, experiment with customizations, and refer back to this guide as needed.
