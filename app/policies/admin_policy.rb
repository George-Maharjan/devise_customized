# Headless policy - not tied to any model
class AdminPolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def index?
    user&.admin?
  end

  def manage_users?
    user&.admin?
  end

  def assign_role?
    user&.admin?
  end

  def deactivate_user?
    user&.admin?
  end

  def activate_user?
    user&.admin?
  end

  def view_analytics?
    user&.admin?
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
