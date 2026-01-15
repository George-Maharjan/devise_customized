class UserPolicy < ApplicationPolicy
  # Only admins can manage users
  def index?
    user&.admin?
  end

  def show?
    user&.admin? || user.id == record.id
  end

  def edit?
    user&.admin? || user.id == record.id
  end

  def update?
    edit?
  end

  def assign_role?
    user&.admin?
  end

  def deactivate?
    user&.admin? && record.id != user.id
  end

  def activate?
    user&.admin? && record.id != user.id
  end

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

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
