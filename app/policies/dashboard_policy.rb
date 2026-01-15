# Headless policy for dashboard access control
# Demonstrates accessing different dashboard features based on user role
class DashboardPolicy < ApplicationPolicy
  def initialize(user)
    @user = user
    @record = nil
  end

  def view?
    user.present?
  end

  def author_dashboard?
    user&.author? || user&.admin?
  end

  def analytics?
    user&.author? || user&.admin?
  end

  def settings?
    user.present?
  end

  def authorization_message
    "You must be logged in to access the dashboard."
  end
end
