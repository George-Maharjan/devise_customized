class BlogPolicy < ApplicationPolicy
  # Helper method to check blog ownership
  def own_blog?
    record.user == user
  end

  # Attribute-level access control for published status
  def view_published_attribute?
    true
  end

  def edit_published_attribute?
    own_blog? || user&.admin?
  end

  # Everyone can view blogs (index and show)
  def index?
    true
  end

  def show?
    # Published blogs are visible to everyone
    # Draft blogs are only visible to owner and admin
    record.published? || own_blog? || user&.admin?
  end

  # Only authors and admins can create blogs
  def new?
    user.present? && (user.author? || user.admin?)
  end

  def create?
    new?
  end

  # Only the blog owner or admin can edit/delete
  def edit?
    user.present? && (own_blog? || user.admin?)
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Different scopes based on user role
      case user
      when nil
        scope.where(published: true)  # Guests see only published blogs
      when ->(u) { u.reader? }
        scope.where(published: true)  # Readers see only published blogs
      when ->(u) { u.author? }
        # Authors see published blogs + their own drafts
        scope.where("published = true OR user_id = ?", user.id)
      when ->(u) { u.admin? }
        scope.all  # Admins see everything
      else
        scope.where(published: true)
      end
    end
  end
end
